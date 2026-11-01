import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname, basename } from 'node:path';
import { EventEmitter } from 'node:events';
import { spawn as realSpawn } from 'node:child_process';

// Safety: read a fixed local source copy only. Its CLI entrypoint and imports are
// not evaluated. Every Git/gh/fs action is mocked; no network or actual claim.
// Only the one explicitly scoped heartbeat probe may spawn a local Node child.
const root = resolve(import.meta.dirname);
const source = readFileSync(join(root, 'scripts/remote-task-claim.mjs'), 'utf8')
  .replace(/^import .*;\n/gm, '')
  .replace('fileURLToPath(import.meta.url)', '"mock-runtime"')
  .split('try { const result = await main();')[0];
const initialClaim = () => ({ task: 'TASK-1', agent: 'review-only', session: 'session-a', branch: 'feat/a', scope: { paths: ['allowed'], modules: [] }, leaseSeconds: 1, generation: 1, status: 'active', expiresAt: new Date(Date.now() + 1000).toISOString(), base: 'mock-base' });
function harness({ command = 'check', state, claim = initialClaim(), onMutate, onSpawn, realChild = false, args = [] } = {}) {
  state ||= { schema: 1, generation: 1, claims: { [claim.task]: claim }, migration: { status: 'open', reservations: [], externalUnknown: false } };
  const r = structuredClone(claim), calls = [], files = new Map([['/mock-receipt', JSON.stringify(r)]]);
  const client = {
    remote: 'mock://not-a-real-remote',
    read: () => ({ state: structuredClone(state) }),
    mutate(change) { onMutate?.(calls, state); calls.push('mutate'); const next = change(structuredClone(state)); state = next; return structuredClone(state); },
  };
  const processStub = {
    argv: ['node', 'mock-cli', command, ...args],
    env: { TASK_CLAIM_SESSION: 'session-a' }, platform: process.platform,
    cwd: () => root, once() {}, removeListener() {},
    kill: (...a) => { calls.push(['kill', ...a]); if (realChild) process.kill(...a); },
  };
  const context = vm.createContext({
    process: processStub, Date, JSON, structuredClone, console,
    resolve, join, dirname, basename,
    setInterval: realChild ? setInterval : () => 1, clearInterval: realChild ? clearInterval : () => {},
    spawnSync(bin, args) {
      calls.push(['mock-spawnSync', bin, ...args]);
      assert.equal(bin, 'git', 'Unexpected process command is blocked');
      if (args[0] === 'symbolic-ref') return { status: 0, stdout: claim.branch };
      if (args[0] === 'rev-parse') return { status: 0, stdout: '/mock-receipt' };
      if (['diff', 'ls-files', 'check-ref-format'].includes(args[0])) return { status: 0, stdout: '' };
      if (args[0] === 'merge-base') return { status: 0, stdout: 'mock-base' };
      throw new Error('Unmocked Git command blocked: ' + args.join(' '));
    },
    spawn(bin, argv, opts) {
      onSpawn?.(state, calls); calls.push('spawn');
      if (realChild) { assert.equal(bin, process.execPath); assert.equal(argv[0], join(root, 'heartbeat-child.mjs')); return realSpawn(bin, argv, opts); }
      const child = new EventEmitter(); child.pid = 424242;
      setImmediate(() => child.emit('close', 0)); return child;
    },
    existsSync: p => files.has(p),
    readFileSync: p => { assert.ok(files.has(p), 'Unmocked file read blocked: ' + p); return files.get(p); },
    writeFileSync: (p, data) => { files.set(p, data); calls.push(['mock-write', p]); },
    lstatSync: () => ({ isSymbolicLink: () => false }),
    mkdirSync() { throw new Error('Actual install/worktree/fs writes blocked'); },
    copyFileSync() { throw new Error('Actual install blocked'); },
    mkdtempSync() { throw new Error('Actual Git client blocked'); },
    randomUUID: () => 'review-only-session',
    __client: client,
  });
  vm.runInContext(source + '\nremoteClient = () => __client; globalThis.api = { runGuarded, owned, checkConflicts, lease, main };', context);
  return { api: context.api, calls, r, client, state: () => state, files };
}

test('repro: a successful but slow renewal launches the child after the lease expired', async () => {
  let launchAfterExpiry = false;
  const h = harness({ command: 'run', args: ['--', 'mock-command'], onSpawn(state) { launchAfterExpiry = Date.parse(state.claims['TASK-1'].expiresAt) <= Date.now(); } });
  assert.equal(h.api.lease(1), 1, 'Production validator explicitly accepts a one-second lease');
  const mutate = h.client.mutate;
  h.client.mutate = change => { const result = mutate(change); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1150); return result; };
  await assert.rejects(h.api.runGuarded(h.client, h.r), /expired/);
  assert.equal(launchAfterExpiry, true, 'Child was already started without valid ownership');
  console.log('REPRO: child launch occurs after confirmed lease expiry; failure arrives only after child exits.');
});

test('repro: synchronous stalled heartbeat cannot stop a real child by expiry', async () => {
  const dir = join(root, 'probe-output'); mkdirSync(dir, { recursive: true });
  const marker = join(dir, 'post-expiry-' + Date.now() + '.json');
  const h = harness({ command: 'run', realChild: true, args: ['--', process.execPath, join(root, 'heartbeat-child.mjs'), marker], onMutate(calls) {
    if (calls.filter(c => c === 'mutate').length >= 1) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 2200);
  } });
  assert.equal(h.api.lease(1), 1, 'Production validator explicitly accepts a one-second lease');
  await assert.rejects(h.api.runGuarded(h.client, h.r), /expired/);
  assert.equal(existsSync(marker), true, 'Real child executed while lease was expired and heartbeat blocked');
  const written = JSON.parse(readFileSync(marker, 'utf8'));
  const expired = Date.parse(h.state().claims['TASK-1'].expiresAt);
  assert.ok(written.at > expired, JSON.stringify({ written, expired }));
  console.log('REPRO:', JSON.stringify({ childWriteMsAfterExpiry: written.at - expired, heartbeatBlockedMs: 2200, leaseMs: 1000 }));
});

test('stale generation remains fenced; unrelated unknown reservations reject overlapping scope', () => {
  const h = harness();
  const stale = { ...h.r, generation: 0 };
  assert.throws(() => h.api.owned(h.state(), stale), /generation/);
  const state = h.state();
  state.migration.reservations.push({ id: 'legacy', task: 'TASK-2', branch: 'feat/legacy', scope: { paths: ['allowed'], modules: [] }, status: 'unknown' });
  assert.throws(() => h.api.checkConflicts(state, { ...h.r, task: 'TASK-3', branch: 'feat/third' }), /Conflict/);
});

test('release is safe but not idempotent: second call is rejected, tombstone remains', async () => {
  const claim = initialClaim(); claim.leaseSeconds = 600; claim.expiresAt = new Date(Date.now() + 600000).toISOString(); claim.remote = 'mock://not-a-real-remote';
  const h = harness({ command: 'release', claim });
  await h.api.main();
  await assert.rejects(h.api.main(), /released|generation/);
  assert.equal(h.state().claims['TASK-1'].status, 'released');
  assert.equal(h.state().generation, 1);
});
