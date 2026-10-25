import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, renameSync, readdirSync, existsSync } from 'node:fs';
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
  writeFileSync(inventory, JSON.stringify({ externalUnknown, reservations }));
  await ok(c, ['init', '--inventory', inventory, '--spec', spec(c, 'TASK-999', ['infra']), '--evidence', 'Disposable test coordinator; legacy executors quarantined'], 'c');
  if (!reservations.length) await ok(c, ['migration-open', '--evidence', 'All disposable test executors accounted for'], 'c');
  return { root, remote, a, b, c, spec };
}
function raceBarrier(remote) {
  writeFileSync(join(remote, 'hooks', 'pre-receive'), '#!/bin/sh\nmkdir -p race\ntouch "race/$$"\nn=0\nwhile [ "$(ls race | wc -l)" -lt 2 ]; do\n n=$((n+1))\n if [ "$n" -gt 200 ]; then exit 1; fi\n sleep 0.05\ndone\n', { mode: 0o755 });
  return () => { assert.ok(readdirSync(join(remote, 'race')).length >= 2, 'two real receive-pack processes reached CAS together'); rmSync(join(remote, 'hooks', 'pre-receive')); };
}

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
  const { a, root, spec } = await fixture(t);
  await ok(a, ['claim', '--spec', spec(a, 'TASK-1', ['parent'])]);
  const target = join(root, 'child');
  await fail(a, ['claim', '--path', target, '--spec', spec(a, 'TASK-1.1', ['child'], [], { session: 'child', branch: 'feat/child' })], 'child', /conflict/i);
  assert.equal(existsSync(target), false);
  await ok(a, ['claim', '--path', target, '--spec', spec(a, 'TASK-2', ['child'], [], { session: 'child', branch: 'feat/child' })], 'child');
  await ok(a, ['check']);
  await ok(target, ['check'], 'child');
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
