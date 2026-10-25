import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, renameSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';

const cli = resolve('scripts/remote-task-claim.mjs');
function git(cwd, ...args) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8', env: process.env });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function ownedGit(cwd, ...args) {
  return spawnSync('git', args, { cwd, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
}
function invoke(cwd, args, session = 'a') {
  return new Promise(resolveResult => {
    const p = spawn(process.execPath, [cli, ...args], { cwd, env: { ...process.env, TASK_CLAIM_SESSION: session } });
    let out = '', err = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { err += d; });
    p.on('close', code => resolveResult({ code, out, err, json: () => JSON.parse(out) }));
  });
}
async function ok(cwd, args, session) {
  const r = await invoke(cwd, args, session); assert.equal(r.code, 0, r.err); return r.json();
}
async function fail(cwd, args, session, pattern = /./) {
  const r = await invoke(cwd, args, session); assert.notEqual(r.code, 0, r.out); assert.match(r.err, pattern); return r;
}
async function waitForFile(path) {
  const deadline = Date.now() + 20000;
  while (!existsSync(path) && Date.now() < deadline) await new Promise(r => setTimeout(r, 50));
  assert.ok(existsSync(path), 'controlled child actually started');
}
async function fixture(t, reservations = [], externalUnknown = false) {
  const root = mkdtempSync(join(tmpdir(), 'task-claim-test-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const remote = join(root, 'remote.git'); git(root, 'init', '--bare', remote);
  const dirs = ['a', 'b', 'c'].map(n => join(root, n));
  for (const d of dirs) {
    git(root, 'clone', remote, d); git(d, 'config', 'user.name', 'Test'); git(d, 'config', 'user.email', 'test@example.invalid');
    git(d, 'checkout', '-b', `feat/test-${dirs.indexOf(d)}`); writeFileSync(join(d, 'seed'), 'seed'); git(d, 'add', '.'); git(d, 'commit', '-m', 'chore: seed');
    writeFileSync(join(d, '.git', 'info', 'exclude'), 'spec.json\nscope.json\n');
  }
  const [a, b, c] = dirs;
  const spec = (d, task, paths = ['src/a'], modules = [], extra = {}) => {
    const p = join(d, 'spec.json');
    writeFileSync(p, JSON.stringify({ task, agent: 'same-account', session: d === a ? 'a' : d === b ? 'b' : 'c', branch: `feat/test-${dirs.indexOf(d)}`, scope: { paths, modules }, leaseSeconds: 600, ...extra }));
    return p;
  };
  const inventory = join(root, 'inventory.json');
  writeFileSync(inventory, JSON.stringify({ externalUnknown, reservations,
    tasks: reservations.filter(r => r.id === `backlog-${r.task}`).map(r => ({ id: r.task, status: 'In Progress' })) }));
  await ok(c, ['init', '--inventory', inventory, '--spec', spec(c, 'TASK-999', ['infra']), '--evidence', 'Disposable test coordinator; legacy executors quarantined'], 'c');
  if (!reservations.length) await ok(c, ['migration-open', '--evidence', 'All disposable test executors accounted for'], 'c');
  return { root, remote, a, b, c, spec };
}
function raceBarrier(remote) {
  writeFileSync(join(remote, 'hooks', 'pre-receive'), '#!/bin/sh\nmkdir -p race\ntouch "race/$$"\nn=0\nwhile [ "$(ls race | wc -l)" -lt 2 ]; do\n n=$((n+1))\n if [ "$n" -gt 200 ]; then exit 1; fi\n sleep 0.05\ndone\n', { mode: 0o755 });
  return () => { assert.ok(readdirSync(join(remote, 'race')).length >= 2, 'two real receive-pack processes reached CAS together'); rmSync(join(remote, 'hooks', 'pre-receive')); };
}

const trackingReason = 'In Progress is not execution ownership; exact executor and scope require acknowledgement';
async function reconciliationFixture(t, outsideOverlap = false) {
  const reservations = [
    { id: 'worktree-a', task: 'TASK-0', branch: 'feat/test-0', scope: { paths: ['allowed'], modules: [] } },
    { id: 'worktree-b', task: 'TASK-0', branch: 'feat/test-1', scope: { paths: ['allowed'], modules: [] } },
    { id: 'backlog-TASK-4.4', task: 'TASK-4.4', branch: null, reason: trackingReason,
      scope: { paths: ['allowed'], modules: ['legacy-gameplay'] } },
    { id: 'outside-owner', task: 'TASK-16', branch: 'feat/warrior75', scope: { paths: [outsideOverlap ? 'allowed' : 'other'], modules: [] } },
  ];
  const f = await fixture(t, reservations, true);
  const snapshot = path => ok(f.c, ['migration-snapshot', '--path', path], 'c');
  const stages = ['TASK-13.1.2', 'TASK-14.1', 'TASK-14.1'].map((task, i) => ({
    id: `stage-${i}`, task, branch: 'feat/reconciled', sources: ['worktree-a', 'worktree-b'],
    scope: { paths: ['allowed'], modules: ['combat'] }, extraPaths: [{ path: 'allowed', reason: 'Explicit bounded test delivery file' }],
  }));
  const manifest = { id: 'm3', executorSession: 'a', evidence: 'Actual source executor confirms both trees frozen; external owner remains held',
    sources: [
      { reservation: 'worktree-a', task: 'TASK-47', role: 'parked-readonly', snapshot: await snapshot(f.a), commits: [] },
      { reservation: 'worktree-b', task: 'TASK-14.1', role: 'parked-readonly', snapshot: await snapshot(f.b), commits: [] },
    ], stages };
  const file = join(f.root, 'manifest.json'); writeFileSync(file, JSON.stringify(manifest));
  return { ...f, manifest, file, reservations };
}

test('reconciliation real commit hooks inspect each parked source index and still reject actual drift', async t => {
  const f = await reconciliationFixture(t);
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  const target = join(f.root, 'execution');
  const spec = f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' });
  await ok(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'Real hook checks frozen sources']);
  await ok(target, ['install']);
  const sources = [f.a, f.b].map(cwd => ({ cwd, index: readFileSync(resolve(cwd, git(cwd, 'rev-parse', '--git-path', 'index'))),
    snapshot: null }));
  for (const source of sources) source.snapshot = await ok(f.c, ['migration-snapshot', '--path', source.cwd], 'c');
  writeFileSync(join(target, 'allowed'), 'first owned change'); git(target, 'add', 'allowed');
  const committed = ownedGit(target, 'commit', '-m', 'test: commit through actual reconciled hooks');
  assert.equal(committed.status, 0, committed.stderr);
  for (const source of sources) {
    assert.deepEqual(await ok(f.c, ['migration-snapshot', '--path', source.cwd], 'c'), source.snapshot);
    assert.deepEqual(readFileSync(resolve(source.cwd, git(source.cwd, 'rev-parse', '--git-path', 'index'))), source.index);
  }
  writeFileSync(join(f.b, 'actual-source-drift'), 'must still be rejected');
  writeFileSync(join(target, 'allowed'), 'second owned change'); git(target, 'add', 'allowed');
  const drifted = ownedGit(target, 'commit', '-m', 'test: reject a genuinely changed source');
  assert.notEqual(drifted.status, 0); assert.match(drifted.stderr, /fingerprint|snapshot|drift/i);
  const wrongSession = spawnSync('git', ['commit', '-m', 'test: reject wrong session'], { cwd: target, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'b' } });
  assert.notEqual(wrongSession.status, 0); assert.match(wrongSession.stderr, /session/i);
});

test('reconciliation preserves every legacy row and only the designated executor adopts serial stages', async t => {
  const f = await reconciliationFixture(t);
  const before = (await ok(f.c, ['list'], 'c')).migration.reservations;
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  const current = await ok(f.c, ['list'], 'c');
  assert.deepEqual(current.migration.reservations, before);
  assert.equal(current.migration.status, 'paused'); assert.equal(current.migration.externalUnknown, true);
  await fail(f.b, ['migration-reconcile', '--manifest', f.file], 'b', /receipt|coordinator/i);
  await fail(f.b, ['adopt', '--spec', f.spec(f.b, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' }), '--group', 'm3', '--stage', 'stage-0', '--evidence', 'wrong executor'], 'b', /executor|session/i);
  await fail(f.a, ['claim', '--spec', f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' })], 'a', /paused/i);
  const target = join(f.root, 'execution');
  const stageSpec = task => f.spec(f.a, task, ['allowed'], ['combat'], { branch: 'feat/reconciled' });
  await ok(f.a, ['adopt', '--spec', stageSpec('TASK-13.1.2'), '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'Source fingerprints confirmed']);
  await ok(target, ['check']);
  await fail(f.a, ['adopt', '--spec', stageSpec('TASK-14.1'), '--group', 'm3', '--stage', 'stage-1', '--evidence', 'parallel stage'], 'a', /stage|active|serial/i);
  await ok(target, ['release', '--stage-complete', 'yes', '--evidence', 'First stage delivered']);
  await fail(target, ['check'], 'a', /ownership|released/i);
  await ok(target, ['adopt', '--spec', stageSpec('TASK-14.1'), '--group', 'm3', '--stage', 'stage-1', '--evidence', 'Second serial stage']);
  const staleReceipt = readFileSync(resolve(target, git(target, 'rev-parse', '--git-path', 'task-claim-receipt.json')), 'utf8');
  await fail(f.a, ['adopt', '--spec', stageSpec('TASK-14.1'), '--group', 'm3', '--stage', 'stage-2', '--evidence', 'same task other stage'], 'a', /active|stage|serial/i);
  await ok(target, ['release', '--stage-complete', 'yes', '--evidence', 'Second stage delivered']);
  await ok(target, ['adopt', '--spec', stageSpec('TASK-14.1'), '--group', 'm3', '--stage', 'stage-2', '--evidence', 'Third serial stage']);
  const receiptPath = resolve(target, git(target, 'rev-parse', '--git-path', 'task-claim-receipt.json'));
  const freshReceipt = readFileSync(receiptPath, 'utf8'); writeFileSync(receiptPath, staleReceipt);
  await fail(target, ['check'], 'a', /ownership|generation/i); writeFileSync(receiptPath, freshReceipt);
  await ok(target, ['check']);
  assert.deepEqual((await ok(f.c, ['list'], 'c')).migration.reservations, before);
});

test('reconciliation rejects source drift, hidden scope, parked-branch writes and unknown external overlaps', async t => {
  const f = await reconciliationFixture(t, true);
  const bad = structuredClone(f.manifest); bad.sources[0].snapshot.head = '0'.repeat(40);
  writeFileSync(f.file, JSON.stringify(bad));
  await fail(f.c, ['migration-reconcile', '--manifest', f.file], 'c', /fingerprint|snapshot|drift/i);
  writeFileSync(f.file, JSON.stringify(f.manifest));
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  const spec = f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' });
  const target = join(f.root, 'execution');
  await fail(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'Cannot cross actual held owner'], 'a', /outside-owner/i);
  writeFileSync(join(f.b, 'changed-after-confirmation'), 'drift');
  await fail(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'stale confirmation'], 'a', /fingerprint|snapshot|drift/i);
  const now = await ok(f.c, ['list'], 'c');
  assert.deepEqual(now.migration.reservations, f.reservations.map(r => ({ ...r, status: 'unknown' })));
});

test('reconciliation CAS revalidates overlapping source groups and never overwrites active claims', async t => {
  const f = await reconciliationFixture(t);
  const other = { ...f.manifest, id: 'duplicate-source-group' };
  const file2 = join(f.root, 'manifest2.json'); writeFileSync(file2, JSON.stringify(other));
  const raced = raceBarrier(f.remote);
  const results = await Promise.all([
    invoke(f.c, ['migration-reconcile', '--manifest', f.file], 'c'),
    invoke(f.c, ['migration-reconcile', '--manifest', file2], 'c'),
  ]);
  raced(); assert.equal(results.filter(r => r.code === 0).length, 1, JSON.stringify(results));
  const state = await ok(f.c, ['list'], 'c');
  assert.equal(Object.keys(state.migration.reconciliations).length, 1);
  assert.deepEqual(state.migration.reservations, f.reservations.map(r => ({ ...r, status: 'unknown' })));
  assert.equal(state.active.find(c => c.task === 'TASK-999').session, 'c');
});

async function adoptedLegacyTarget(t, secondStage = false) {
  const f = await reconciliationFixture(t);
  f.manifest.sources[0].role = 'executor-target'; f.manifest.sources[0].task = 'TASK-13.1.2';
  f.manifest.stages = [{ ...f.manifest.stages[0], branch: 'feat/test-0' }];
  if (secondStage) f.manifest.stages.push({ ...f.manifest.stages[0], id: 'stage-1' });
  writeFileSync(f.file, JSON.stringify(f.manifest));
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  await ok(f.a, ['adopt', '--spec', f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat']),
    '--group', 'm3', '--stage', 'stage-0', '--evidence', 'Actual legacy executor adopts its existing target']);
  return f;
}

test('reconciliation prevents ordinary recover from dropping designated executor and stage restrictions', async t => {
  const f = await adoptedLegacyTarget(t);
  await ok(f.a, ['release']);
  await fail(f.b, ['recover', '--spec', f.spec(f.b, 'TASK-13.1.2', ['unrelated-escape'], [], { branch: 'feat/escape' }),
    '--evidence', 'Must not turn a released stage into an ungrouped claim'], 'b', /reconcil|group|stage/i);
  await ok(f.a, ['adopt', '--spec', f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat']),
    '--group', 'm3', '--stage', 'stage-0', '--evidence', 'Designated executor resumes the same released stage']);
});

test('reconciliation prevents an explicit future file from becoming an unrestricted directory prefix', async t => {
  const f = await adoptedLegacyTarget(t);
  mkdirSync(join(f.a, 'allowed')); writeFileSync(join(f.a, 'allowed', 'hidden.lua'), 'out of scope');
  await fail(f.a, ['check', '--paths', 'dirty'], 'a', /scope/i);
});

test('reconciliation resumes its actual executor after interrupted work without trusting a different target', async t => {
  const f = await adoptedLegacyTarget(t);
  writeFileSync(join(f.a, 'allowed'), 'legitimate unfinished delivery');
  await ok(f.a, ['check', '--paths', 'dirty']);
  await ok(f.a, ['release']);
  const spec = f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat']);
  await fail(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--path', join(f.root, 'impostor'), '--evidence', 'Do not move a mutable source'], 'a', /target|fingerprint|snapshot|drift/i);
  await ok(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--evidence', 'Actual designated executor resumes its own retained work']);
  await ok(f.a, ['check', '--paths', 'dirty']);
});

test('reconciliation permits the same execution target to finish a later approved stage after handoff', async t => {
  const f = await adoptedLegacyTarget(t, true);
  writeFileSync(join(f.a, 'allowed'), 'stage one');
  await ok(f.a, ['release', '--stage-complete', 'yes', '--evidence', 'Owner explicitly hands off stage one']);
  await ok(f.a, ['adopt', '--spec', f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat']), '--group', 'm3', '--stage', 'stage-1', '--evidence', 'Same owner starts the next approved stage']);
  writeFileSync(join(f.a, 'allowed'), 'stage two');
  await ok(f.a, ['check', '--paths', 'dirty']);
  await ok(f.a, ['release', '--stage-complete', 'yes', '--evidence', 'Owner explicitly hands off stage two']);
});

test('reconciliation continuously verifies an external owners released handoff', async t => {
  const f = await fixture(t, [
    { id: 'owner', task: 'TASK-0', branch: 'feat/test-0', scope: { paths: ['allowed'], modules: [] } },
    { id: 'consumer', task: 'TASK-0', branch: 'feat/test-1', scope: { paths: ['other'], modules: [] } },
  ], true);
  const register = async (id, cwd, session, task, role, branch) => {
    const manifest = { id, executorSession: session, evidence: 'Actual owner confirms exact frozen delivery',
      sources: [{ reservation: id, task, role, snapshot: await ok(cwd, ['migration-snapshot', '--path', cwd], session), commits: [] }],
      stages: [{ id: 'delivery', task, branch, sources: [id], scope: { paths: ['allowed'], modules: [] }, extraPaths: [{ path: 'allowed', reason: 'Shared delivery file' }] }] };
    const path = join(f.root, `${id}.json`); writeFileSync(path, JSON.stringify(manifest));
    await ok(f.c, ['migration-reconcile', '--manifest', path], 'c');
  };
  await register('owner', f.a, 'a', 'TASK-16', 'executor-target', 'feat/test-0');
  await ok(f.a, ['adopt', '--spec', f.spec(f.a, 'TASK-16', ['allowed']), '--group', 'owner', '--stage', 'delivery', '--evidence', 'Actual owner continues']);
  writeFileSync(join(f.a, 'allowed'), 'owner delivery');
  await ok(f.a, ['release', '--stage-complete', 'yes', '--evidence', 'Actual owner explicitly releases shared path']);
  await register('consumer', f.b, 'b', 'TASK-47', 'parked-readonly', 'feat/consumer');
  const target = join(f.root, 'consumer-execution');
  await ok(f.b, ['adopt', '--spec', f.spec(f.b, 'TASK-47', ['allowed'], [], { branch: 'feat/consumer' }), '--group', 'consumer', '--stage', 'delivery', '--path', target, '--evidence', 'Consume confirmed external handoff'], 'b');
  await ok(target, ['check'], 'b');
  writeFileSync(join(f.a, 'allowed'), 'external owner resumed without a valid handoff');
  await fail(target, ['check'], 'b', /fingerprint|snapshot|drift/i);
  await fail(target, ['renew'], 'b', /fingerprint|snapshot|drift/i);
});

test('real independent processes: same task has exactly one winner; repeat claim is not another owner', async t => {
  const { a, b, remote, spec } = await fixture(t);
  const raced = raceBarrier(remote);
  const r = await Promise.all([invoke(a, ['claim', '--spec', spec(a, 'TASK-1')]), invoke(b, ['claim', '--spec', spec(b, 'TASK-1')], 'b')]);
  raced();
  assert.equal(r.filter(x => x.code === 0).length, 1, JSON.stringify(r));
  const winner = r[0].code === 0 ? a : b, session = winner === a ? 'a' : 'b';
  await ok(winner, ['check'], session);
  await fail(winner, ['claim', '--spec', join(winner, 'spec.json')], session, /already|conflict/i);
});

test('disjoint claims survive CAS retry without losing either update', async t => {
  const { a, b, remote, spec } = await fixture(t);
  const raced = raceBarrier(remote);
  const r = await Promise.all([invoke(a, ['claim', '--spec', spec(a, 'TASK-1', ['src/a'])]), invoke(b, ['claim', '--spec', spec(b, 'TASK-2', ['src/b'])], 'b')]);
  raced();
  assert.deepEqual(r.map(x => x.code), [0, 0], JSON.stringify(r));
  assert.equal((await ok(a, ['list'])).active.length, 3);
});

test('parent-child, canonical overlapping paths and shared modules conflict', async t => {
  const { a, b, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['src/Combat'], ['combat'])]);
  for (const [task, paths, modules] of [['TASK-1.2', ['other'], []], ['task-0001', ['other'], []], ['TASK-2', ['SRC/combat/core.lua'], []], ['TASK-3', ['other'], ['combat']]]) {
    await fail(b, ['claim', '--spec', spec(b, task, paths, modules)], 'b', /conflict/i);
  }
  await fail(b, ['claim', '--spec', spec(b, 'TASK-4', [])], 'b', /scope|path/i);
  await fail(b, ['claim', '--spec', spec(b, 'TASK-4', ['src/../other'])], 'b', /path/i);
});

test('expired recovery fences old renew, release, check and guarded commands', async t => {
  const { a, b, spec } = await fixture(t);
  const first = await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['src/a'], [], { leaseSeconds: 4 })]);
  await new Promise(r => setTimeout(r, 4500));
  const next = await ok(b, ['recover', '--spec', spec(b, 'TASK-1'), '--evidence', 'Old process terminated'], 'b');
  assert.ok(next.generation > first.generation);
  for (const command of ['renew', 'release', 'check']) await fail(a, [command], 'a', /ownership|expired|generation/i);
  const marker = join(a, 'ran');
  await fail(a, ['run', '--', process.execPath, '-e', `require('fs').writeFileSync(${JSON.stringify(marker)},'bad')`]);
  assert.throws(() => readFileSync(marker));
  await fail(b, ['release'], 'a', /session/i);
});

test('concurrent renewal/release never resurrects released ownership or loses other task', async t => {
  const { a, b, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1')]);
  await ok(b, ['claim', '--spec', spec(b, 'TASK-2', ['src/b'])], 'b');
  const r = await Promise.all([invoke(a, ['renew']), invoke(a, ['release']), invoke(b, ['renew'], 'b')]);
  assert.equal(r[1].code, 0, r[1].err); assert.equal(r[2].code, 0, r[2].err);
  await fail(a, ['check']); await ok(b, ['check'], 'b');
});

test('unreachable remote and receive-hook rejection never report successful claims', async t => {
  const { a, remote, spec } = await fixture(t);
  writeFileSync(join(remote, 'hooks', 'pre-receive'), '#!/bin/sh\nexit 1\n', { mode: 0o755 });
  await fail(a, ['claim', '--spec', spec(a, 'TASK-1')], 'a', /push|reject/i);
  rmSync(join(remote, 'hooks', 'pre-receive'));
  await ok(a, ['claim', '--spec', join(a, 'spec.json')]);
  renameSync(remote, remote + '.offline');
  for (const command of [['list'], ['check'], ['renew'], ['release'], ['run', '--', process.execPath, '-e', 'process.exit(0)']]) await fail(a, command, 'a', /remote|unreachable|failed/i);
});

test('paused migration refuses fresh work; adoption requires evidence and rejects unresolved reservations', async t => {
  const legacy = { id: 'legacy-a', task: 'TASK-1', branch: 'feat/test-0', scope: { paths: ['src/a'], modules: [] }, status: 'unknown' };
  const { a, b, c, spec } = await fixture(t, [legacy]);
  await fail(a, ['claim', '--spec', spec(a, 'TASK-2', ['other'])], 'a', /migration/i);
  await fail(a, ['adopt', '--spec', spec(a, 'TASK-1'), '--reservation', 'legacy-a'], 'a', /evidence/i);
  await fail(c, ['migration-open', '--evidence', 'still unknown'], 'c', /unresolved/i);
  await ok(a, ['adopt', '--spec', spec(a, 'TASK-1'), '--reservation', 'legacy-a', '--evidence', 'Prior executor stopped and work retained']);
  await fail(b, ['adopt', '--spec', spec(b, 'TASK-1'), '--reservation', 'legacy-a', '--evidence', 'duplicate'], 'b');
  await ok(a, ['check']);
});

test('scope expansion is CAS checked and pre-commit/pre-push reject stale or out-of-scope sessions', async t => {
  const { a, b, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['allowed'])]);
  await ok(b, ['claim', '--spec', spec(b, 'TASK-2', ['blocked'])], 'b');
  const scope = join(a, 'scope.json'); writeFileSync(scope, JSON.stringify({ paths: ['allowed', 'blocked'], modules: [] }));
  await fail(a, ['expand', '--scope', scope], 'a', /conflict/i);
  writeFileSync(scope, JSON.stringify({ paths: ['allowed', 'extra'], modules: [] }));
  assert.deepEqual((await ok(a, ['expand', '--scope', scope])).scope.paths, ['allowed', 'extra']);
  await ok(a, ['install']);
  writeFileSync(join(a, 'blocked'), 'oops'); git(a, 'add', 'blocked');
  const commit = spawnSync('git', ['commit', '-m', 'test: blocked'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.notEqual(commit.status, 0); assert.match(commit.stderr, /scope/i);
  git(a, 'reset', '--', 'blocked');
  writeFileSync(join(a, 'allowed'), 'yes'); git(a, 'add', 'allowed');
  const missing = spawnSync('git', ['commit', '-m', 'test: missing session'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: '' } });
  assert.notEqual(missing.status, 0); assert.match(missing.stderr, /session/i);
  const commitAllowed = spawnSync('git', ['commit', '-m', 'test: allowed'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.equal(commitAllowed.status, 0, commitAllowed.stderr);
  const head = git(a, 'rev-parse', 'HEAD');
  await fail(a, ['verify-pr', '--branch', 'feat/test-0', '--sha', head], 'a', /authorization/i);
  const pushAllowed = spawnSync('git', ['push', 'origin', 'HEAD:refs/heads/feat/test-0'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.equal(pushAllowed.status, 0, pushAllowed.stderr);
  const pushAgain = spawnSync('git', ['push', 'origin', 'HEAD:refs/heads/feat/test-0'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.equal(pushAgain.status, 0, pushAgain.stderr);
  await ok(a, ['verify-pr', '--branch', 'feat/test-0', '--sha', head]);
  await ok(a, ['release']);
  await fail(a, ['verify-pr', '--branch', 'feat/test-0', '--sha', head]);
  await fail(a, ['hook', 'push'], 'a', /ownership|released/i);
  writeFileSync(join(a, 'allowed'), 'lost owner'); git(a, 'add', 'allowed');
  const commitLost = spawnSync('git', ['commit', '--no-verify', '-m', 'test: cannot bypass ownership'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.notEqual(commitLost.status, 0); assert.match(commitLost.stderr, /ownership|released/i);
  const pushLost = spawnSync('git', ['push', 'origin', 'HEAD:refs/heads/feat/lost'], { cwd: a, encoding: 'utf8', env: { ...process.env, TASK_CLAIM_SESSION: 'a' } });
  assert.notEqual(pushLost.status, 0); assert.match(pushLost.stderr, /ownership|released/i);
});

test('interrupted executor leaves a recoverable lease; restart never grants old receipt a new generation', async t => {
  const { a, b, spec } = await fixture(t);
  const original = await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['allowed'], [], { leaseSeconds: 20 })]);
  const p = spawn(process.execPath, [cli, 'run', '--', process.execPath, '-e', "require('fs').writeFileSync('allowed',String(process.pid));setTimeout(()=>{},60000)"], { cwd: a, env: { ...process.env, TASK_CLAIM_SESSION: 'a' }, stdio: 'ignore' });
  await waitForFile(join(a, 'allowed'));
  if (process.platform === 'win32') spawnSync('taskkill', ['/pid', String(p.pid), '/T', '/F'], { windowsHide: true });
  else { p.kill('SIGKILL'); if (existsSync(join(a, 'allowed'))) { try { process.kill(-Number(readFileSync(join(a, 'allowed'), 'utf8')), 'SIGKILL'); } catch { /* already stopped */ } } }
  await new Promise(r => p.exitCode !== null ? r() : p.once('close', r));
  await new Promise(r => setTimeout(r, 21000));
  const next = await ok(b, ['recover', '--spec', spec(b, 'TASK-1', ['allowed']), '--evidence', 'Interrupted process tree stopped'], 'b');
  assert.ok(next.generation > original.generation);
  await fail(a, ['check']);
  await ok(b, ['release'], 'b');
  await ok(a, ['recover', '--spec', spec(a, 'TASK-1', ['allowed']), '--evidence', 'Explicit new session after release']);
  await ok(a, ['check']);
});

test('unknown external executors prevent opening migration; evidence-based resolution is explicit', async t => {
  const legacy = { id: 'old', task: 'TASK-1', branch: 'feat/test-0', scope: { paths: ['src/a'], modules: [] } };
  const { a, c, spec } = await fixture(t, [legacy], true);
  await fail(a, ['adopt', '--spec', spec(a, 'TASK-1', ['narrow']), '--reservation', 'old', '--evidence', 'stopped'], 'a', /scope/i);
  await ok(c, ['migration-resolve', '--reservation', 'old', '--evidence', 'Old executor stopped; branch preserved'], 'c');
  await fail(c, ['migration-open', '--evidence', 'External sessions still unknown'], 'c', /unknown|unresolved/i);
  await ok(c, ['migration-resolve', '--external-reviewed', 'yes', '--evidence', 'All disposable external sessions reviewed and stopped'], 'c');
  await ok(c, ['migration-open', '--evidence', 'Disposable executors fully reviewed'], 'c');
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1')]);
});

test('claim then controlled worktree transfers the receipt without altering existing directories', async t => {
  const { a, root, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['allowed'], [], { branch: 'feat/isolated' })]);
  await fail(a, ['check'], 'a', /branch/i);
  await fail(a, ['worktree', '--path', a], 'a', /exists/i);
  const target = join(root, 'isolated');
  await ok(a, ['worktree', '--path', target]);
  await ok(target, ['check']);
  await ok(target, ['install']);
  writeFileSync(join(target, 'allowed'), 'valid');
  await ok(target, ['run', '--', process.execPath, '-e', 'process.exit(0)']);
  await ok(target, ['release']);
});

test('released installation coordinator can recover its exact quarantined scope; migration cannot deadlock', async t => {
  const legacy = { id: 'old-infra', task: 'TASK-1', scope: { paths: ['infra'], modules: [] } };
  const { a, c, spec } = await fixture(t, [legacy], true);
  await ok(c, ['release'], 'c');
  await fail(a, ['recover', '--spec', spec(a, 'TASK-999', ['infra', 'other']), '--evidence', 'new coordinator'], 'a', /scope/i);
  await ok(a, ['recover', '--spec', spec(a, 'TASK-999', ['infra']), '--evidence', 'Original coordinator stopped; same narrow installation scope']);
  await ok(a, ['migration-resolve', '--reservation', 'old-infra', '--evidence', 'Prior infra executor stopped, historical work preserved']);
  await ok(a, ['migration-resolve', '--external-reviewed', 'yes', '--evidence', 'Disposable executors accounted for']);
  await ok(a, ['migration-open', '--evidence', 'All disposable entrypoints upgraded']);
});

test('remote loss during controlled development terminates the real child before further work', async t => {
  const { a, remote, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['allowed'], [], { leaseSeconds: 12 })]);
  const p = spawn(process.execPath, [cli, 'run', '--', process.execPath, '-e', "const fs=require('fs');fs.mkdirSync('allowed');fs.writeFileSync('allowed/started','yes');setTimeout(()=>fs.writeFileSync('allowed/after','bad'),10000)"], { cwd: a, env: { ...process.env, TASK_CLAIM_SESSION: 'a' }, stdio: ['ignore', 'pipe', 'pipe'] });
  let err = ''; p.stderr.on('data', d => { err += d; });
  const closed = new Promise(r => p.once('close', r));
  await waitForFile(join(a, 'allowed', 'started'));
  renameSync(remote, remote + '.offline');
  const code = await closed;
  assert.notEqual(code, 0); assert.match(err, /remote|unreachable|failed/i);
  assert.equal(existsSync(join(a, 'allowed', 'after')), false);
});

test('child executor acquisition creates an isolated receipt and never borrows the parent session', async t => {
  const { a, b, root, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['parent'])]);
  writeFileSync(join(b, 'upstream'), 'latest integration base'); git(b, 'add', 'upstream'); git(b, 'commit', '-m', 'test: advance integration');
  git(b, 'push', 'origin', 'HEAD:refs/heads/develop'); git(a, 'fetch', 'origin', 'develop');
  const latest = git(a, 'rev-parse', 'origin/develop');
  const target = join(root, 'child');
  await fail(a, ['claim', '--path', target, '--spec', spec(a, 'TASK-1.1', ['child'], [], { session: 'child', branch: 'feat/child' })], 'child', /conflict/i);
  assert.equal(existsSync(target), false);
  await ok(a, ['claim', '--path', target, '--spec', spec(a, 'TASK-2', ['child'], [], { session: 'child', branch: 'feat/child' })], 'child');
  await ok(a, ['check']);
  await ok(target, ['check'], 'child');
  assert.equal(git(target, 'rev-parse', 'HEAD'), latest, 'new child starts from fetched develop, not stale parent HEAD');
  assert.equal(readFileSync(join(target, 'upstream'), 'utf8'), 'latest integration base');
  await fail(target, ['check'], 'a', /session/i);
  await ok(target, ['release'], 'child');
  await ok(a, ['check']);
});

test('conflicting upstream merge preserves upstream files without authorizing out-of-scope resolutions', async t => {
  const { a, b, spec } = await fixture(t);
  git(a, 'push', 'origin', 'HEAD:refs/heads/develop'); git(a, 'fetch', 'origin', 'develop');
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['allowed'])]); await ok(a, ['install']);
  writeFileSync(join(a, 'allowed'), 'ours'); git(a, 'add', 'allowed');
  const own = ownedGit(a, 'commit', '-m', 'test: owned changes'); assert.equal(own.status, 0, own.stderr);
  git(b, 'fetch', 'origin', 'develop'); git(b, 'checkout', '-B', 'develop', 'origin/develop');
  writeFileSync(join(b, 'allowed'), 'upstream'); writeFileSync(join(b, 'upstream'), 'retained');
  git(b, 'add', '.'); git(b, 'commit', '-m', 'test: upstream changes'); git(b, 'push', 'origin', 'develop');
  const base = git(b, 'rev-parse', 'HEAD');
  git(a, 'fetch', 'origin', 'develop');
  assert.notEqual(ownedGit(a, 'merge', '--no-edit', 'origin/develop').status, 0);
  writeFileSync(join(a, 'allowed'), 'resolved'); git(a, 'add', 'allowed');
  writeFileSync(join(a, 'upstream'), 'unauthorized resolution'); git(a, 'add', 'upstream');
  await fail(a, ['sync-base', '--base', base]);
  writeFileSync(join(a, 'upstream'), 'retained'); git(a, 'add', 'upstream');
  await ok(a, ['sync-base', '--base', base]);
  // The installed runtime must apply the same merge guard as the current CLI.
  await ok(a, ['install']);
  const merge = ownedGit(a, 'commit', '-m', 'test: resolve owned merge conflict'); assert.equal(merge.status, 0, merge.stderr);
  assert.equal(readFileSync(join(a, 'upstream'), 'utf8'), 'retained');
  const pushed = ownedGit(a, 'push', 'origin', 'HEAD:refs/heads/feat/test-0'); assert.equal(pushed.status, 0, pushed.stderr);
});
