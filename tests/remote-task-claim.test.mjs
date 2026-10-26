import { gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, renameSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { runInNewContext } from 'node:vm';

const cli = resolve('scripts/remote-task-claim.mjs');
function leaseBoundary({lateInitial=false}={}) {
  const raw=readFileSync(cli,'utf8'),start=raw.indexOf('async function runGuarded(');
  const body=raw.slice(start,raw.indexOf('\nasync function main()',start));
  const receipt={task:'TASK-1',session:'fixture',generation:1,branch:'feat/fixture'};
  const claim={...receipt,status:'active',leaseSeconds:1,expiresAt:new Date(Date.now()+5000).toISOString()};
  const state={claims:{'TASK-1':claim}},children=new Map();let mutations=0,launched=0,pid=100;
  const owned=s=>{if(Date.parse(s.claims['TASK-1'].expiresAt)<=Date.now())throw new Error('Ownership expired');return s.claims['TASK-1'];};
  const client={read:()=>({state}),mutate(fn){fn(state);mutations++;
    if((lateInitial&&mutations===1)||(!lateInitial&&mutations>1))Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,lateInitial?1150:1500);
    return state;
  }};
  const fakeSpawn=(command,args)=>{
    const child=new EventEmitter();child.pid=++pid;child.stdout=new EventEmitter();child.stderr=new EventEmitter();
    const primary=command==='fixture-child';if(primary)launched++;
    const timer=setTimeout(()=>{
      if(!primary)child.stdout.emit('data',JSON.stringify(claim));
      child.emit('close',0);
    },primary?1600:1500);
    child.stop=()=>{clearTimeout(timer);child.emit('close',1);};children.set(child.pid,child);return child;
  };
  const run=runInNewContext('('+body+')',{rest:['fixture-child'],owned,requireState:s=>s,
    checkPaths(){},changedPaths:()=>[],now:Date.now,spawn:fakeSpawn,spawnSync(){},
    setInterval,clearInterval,setTimeout,clearTimeout,runtimeFile:'/fixture/runtime.mjs',
    process:{platform:'linux',execPath:process.execPath,env:{},once(){},removeListener(){},
      kill(id){children.get(Math.abs(id))?.stop();}},die(message){throw new Error(message);}});
  return {run:()=>run(client,receipt),launched:()=>launched};
}

test('a renewal completed after its own expiry cannot launch any child',async()=>{
  const f=leaseBoundary({lateInitial:true});await assert.rejects(f.run(),/expired/i);
  assert.equal(f.launched(),0,'slow initial remote renewal must be rechecked before spawn');
});

test('local execution deadline remains live while remote renewal is slow',async()=>{
  const f=leaseBoundary(),started=Date.now();await assert.rejects(f.run(),/expired/i);
  assert.equal(f.launched(),1);assert(Date.now()-started<1450,'blocked remote I/O must not extend the local lease');
});

test('canonical renewal helper keeps a real child alive beyond its initial lease',async t=>{
  const f=await fixture(t);
  await ok(f.a,['claim','--spec',f.spec(f.a,'TASK-1',['allowed'],[],{leaseSeconds:10})]);
  await ok(f.a,['run','--',process.execPath,'-e',
    'setTimeout(()=>require("node:fs").writeFileSync("allowed","renewed"),11500)']);
  assert.equal(readFileSync(join(f.a,'allowed'),'utf8'),'renewed');
  git(f.a,'fetch','origin','coord/task-claims');
  assert.match(git(f.a,'log','origin/coord/task-claims','--format=%s'),/chore\(claim\): renew/);
});
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
test('only coordinator transfers a released group at its exact clean published head, preserving history', async t => {
  const f = await reconciliationFixture(t);
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  const target = join(f.root, 'execution');
  const spec = f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' });
  await ok(f.a, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'Initial stage']);
  const sha = git(target, 'rev-parse', 'HEAD');
  git(target, 'push', 'origin', 'HEAD:refs/heads/feat/reconciled');
  const args = ['migration-transfer', '--group', 'm3', '--from-session', 'a', '--to-session', 'b', '--sha', sha, '--evidence', 'User explicitly assigned new integration session; old executor stopped'];
  await fail(f.c, args, 'c', /idle|active/i);
  await ok(target, ['release']);
  await fail(f.b, args, 'b', /receipt|coordinator/i);
  await fail(f.c, args.map(x => x === sha ? '0'.repeat(40) : x), 'c', /head|sha/i);
  writeFileSync(join(target, 'allowed'), 'uncommitted');
  await fail(f.c, args, 'c', /clean|dirty/i);
  rmSync(join(target, 'allowed'));
  const before = await ok(f.c, ['list'], 'c');
  await ok(f.c, args, 'c');
  const after = await ok(f.c, ['list'], 'c');
  const old = before.migration.reconciliations.m3, next = after.migration.reconciliations.m3;
  assert.deepEqual(next.sources, old.sources); assert.deepEqual(next.stages, old.stages);
  assert.equal(next.cursor, old.cursor); assert.equal(next.executorSession, 'b');
  assert.equal(next.transfers.at(-1).previousSession, 'a');
  assert.equal(next.transfers.at(-1).head, sha);
  assert.deepEqual(after.released, before.released);
  assert.deepEqual(after.migration.reservations, before.migration.reservations);
  assert.equal(after.migration.status, 'paused'); assert.equal(after.migration.externalUnknown, true);
  await fail(target, ['adopt', '--spec', spec, '--group', 'm3', '--stage', 'stage-0', '--evidence', 'Old executor rejected'], 'a', /executor|session/i);
  const newSpec = f.spec(f.b, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' });
  const adopted = await ok(target, ['adopt', '--spec', newSpec, '--group', 'm3', '--stage', 'stage-0', '--evidence', 'Authorized transfer'], 'b');
  assert.ok(adopted.generation > before.released.find(x => x.task === 'TASK-13.1.2').generation);
});
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

test('coordinator can add exact regression files only to idle remaining reconciliation stages', async t => {
  const f = await reconciliationFixture(t);
  await ok(f.c, ['migration-reconcile', '--manifest', f.file], 'c');
  const target = join(f.root, 'execution');
  await ok(f.a, ['adopt', '--spec', f.spec(f.a, 'TASK-13.1.2', ['allowed'], ['combat'], { branch: 'feat/reconciled' }), '--group', 'm3', '--stage', 'stage-0', '--path', target, '--evidence', 'Initial stage']);
  const extended = structuredClone(f.manifest);
  for (const stage of extended.stages.slice(1)) {
    stage.scope.paths.push('regression.lua'); stage.extraPaths.push({ path: 'regression.lua', reason: 'Preserve added content regression coverage' });
  }
  writeFileSync(f.file, JSON.stringify(extended));
  await fail(f.c, ['migration-reconcile', '--manifest', f.file, '--extend', 'yes', '--evidence', 'Cannot change an active group'], 'c', /active|idle/i);
  await ok(target, ['release', '--stage-complete', 'yes', '--evidence', 'Initial stage delivered']);
  const before = await ok(f.c, ['list'], 'c');
  await ok(f.c, ['migration-reconcile', '--manifest', f.file, '--extend', 'yes', '--evidence', 'Owner authorized exact omitted regression file'], 'c');
  const after = await ok(f.c, ['list'], 'c');
  const old = before.migration.reconciliations.m3, group = after.migration.reconciliations.m3;
  assert.equal(group.cursor, 1); assert.deepEqual(group.completed, old.completed); assert.deepEqual(group.sources, old.sources);
  assert.deepEqual(group.stages[0], old.stages[0]); assert.deepEqual(after.migration.reservations, before.migration.reservations);
  assert.equal(group.amendments.length, 1); assert.equal(group.amendments[0].previousManifestSha256, old.manifestSha256);
  const past = structuredClone(extended); past.stages[0].scope.paths.push('regression.lua'); past.stages[0].extraPaths.push({path:'regression.lua',reason:'Cannot rewrite completed stage'});
  writeFileSync(f.file, JSON.stringify(past));
  await fail(f.c, ['migration-reconcile', '--manifest', f.file, '--extend', 'yes', '--evidence', 'Must preserve past stage'], 'c', /completed|past/i);
  const changedOwner = structuredClone(extended); changedOwner.executorSession = 'b'; writeFileSync(f.file, JSON.stringify(changedOwner));
  await fail(f.c, ['migration-reconcile', '--manifest', f.file, '--extend', 'yes', '--evidence', 'Cannot move executor'], 'c', /executor|identity/i);
  await ok(target, ['adopt', '--spec', f.spec(f.a, 'TASK-14.1', ['allowed','regression.lua'], ['combat'], { branch: 'feat/reconciled' }), '--group', 'm3', '--stage', 'stage-1', '--evidence', 'Next exact scope']);
  writeFileSync(join(target, 'regression.lua'), '-- scoped regression'); await ok(target, ['check', '--paths', 'dirty']);
});

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

test('bounded admission preserves paused migration and fences exact task session files and legacy overlaps', async t => {
  const legacy={id:'old-owner',task:'TASK-0',branch:'feat/old',scope:{paths:['src'],modules:['combat']}};
  const f=await fixture(t,[legacy],true);
  const manifest={id:'v4-only',task:'TASK-61',executorSession:'a',branch:'feat/v4',scope:{paths:['src/v4.lua'],modules:['combat']},
    acknowledgedReservations:['old-owner'],evidence:'User authorizes only V4 exact scope; legacy remains quarantined, not declared stopped'};
  const file=join(f.root,'admission.json');writeFileSync(file,JSON.stringify(manifest));
  const before=await ok(f.c,['list'],'c');
  await fail(f.b,['migration-admit','--manifest',file],'b',/receipt|coordinator/i);
  const bad={...manifest,acknowledgedReservations:[]};writeFileSync(file,JSON.stringify(bad));
  await fail(f.c,['migration-admit','--manifest',file],'c',/acknowledg|overlap/i);
  writeFileSync(file,JSON.stringify({...manifest,branch:'feat/old'}));
  await fail(f.c,['migration-admit','--manifest',file],'c',/new branch|takeover/i);
  writeFileSync(file,JSON.stringify({...manifest,scope:{paths:['infra/file.lua'],modules:[]},acknowledgedReservations:[]}));
  await fail(f.c,['migration-admit','--manifest',file],'c',/conflict/i);
  writeFileSync(file,JSON.stringify(manifest));
  await ok(f.c,['migration-admit','--manifest',file],'c');
  const after=await ok(f.c,['list'],'c');
  assert.deepEqual(after.migration.reservations,before.migration.reservations);
  assert.equal(after.migration.status,'paused');assert.equal(after.migration.externalUnknown,true);
  await fail(f.c,['migration-admit','--manifest',file],'c',/already|immutable/i);
  const spec=f.spec(f.a,'TASK-61',['src/v4.lua'],['combat'],{branch:'feat/v4'});
  await fail(f.a,['claim','--spec',spec],'a',/admission approval required/i);
  await fail(f.b,['claim','--spec',f.spec(f.b,'TASK-61',['src/v4.lua'],['combat'],{branch:'feat/v4'}),'--admission','v4-only'],'b',/admission|executor|session/i);
  const target=join(f.root,'v4');
  await ok(f.a,['claim','--spec',spec,'--admission','v4-only','--path',target]);
  await ok(target,['check']);
  await fail(target,['migration-admit','--manifest',file],'a',/coordinator/i);
  writeFileSync(file,JSON.stringify({...manifest,id:'v4-child',task:'TASK-61.1',branch:'feat/child'}));
  await fail(f.c,['migration-admit','--manifest',file],'c',/new task|takeover/i);
  mkdirSync(join(target,'src'));writeFileSync(join(target,'src','v4.lua'),'return {}');
  await ok(target,['check','--paths','dirty']);
  writeFileSync(join(target,'src','other.lua'),'out of scope');
  await fail(target,['check','--paths','dirty'],'a',/out of scope/i);
  rmSync(join(target,'src','other.lua'));
  const expanded=join(f.root,'expanded.json');writeFileSync(expanded,JSON.stringify({paths:['src'],modules:['combat']}));
  await fail(target,['expand','--scope',expanded],'a',/admission|exact/i);
  await ok(target,['release']);
  await fail(target,['check'],'a',/lost|released/i);
  await ok(target,['recover','--spec',spec,'--admission','v4-only','--evidence','Same approved executor resumes exact V4 scope']);
  await ok(target,['check']);
});


test('admission rejects actual pre-admission runtime push authorization and recover label removal', async t => {
  const f=await fixture(t,[{id:'unrelated',task:'TASK-0',branch:'feat/parked',scope:{paths:['parked'],modules:[]}}],true);
  const manifest={id:'v4-fenced',task:'TASK-61',executorSession:'a',branch:'feat/v4',scope:{paths:['v4.lua'],modules:[]},
    acknowledgedReservations:[],evidence:'Only current V4 executor; unknown outside work preserved'};
  const file=join(f.root,'admission.json');writeFileSync(file,JSON.stringify(manifest));
  await ok(f.c,['migration-admit','--manifest',file],'c');
  const target=join(f.root,'v4');
  const spec=f.spec(f.a,'TASK-61',['v4.lua'],[],{branch:'feat/v4'});
  await ok(f.a,['claim','--spec',spec,'--admission','v4-fenced','--path',target]);
  const legacy=join(f.root,'legacy.mjs');
  // Exact unmodified 45ba918 runtime, embedded so shallow CI needs no history/network.
  const legacySource=gunzipSync(Buffer.from('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','base64'));
  assert.equal(createHash('sha256').update(legacySource).digest('hex'),'9f197a0d2140fe54f7f4a14c30571d149cd5201937360b2f8ff5929eac53ebb6');
  writeFileSync(legacy,legacySource);
  const legacyRun=(cwd,args,executor,input)=>spawnSync(process.execPath,[legacy,...args],{
    cwd,encoding:'utf8',input,env:{...process.env,TASK_CLAIM_SESSION:executor}});
  writeFileSync(join(target,'v4.lua'),'return {}');git(target,'add','v4.lua');git(target,'commit','-m','test: admitted card');
  const head=git(target,'rev-parse','HEAD');
  const input=`HEAD ${head} refs/heads/feat/v4 ${'0'.repeat(40)}\n`;
  const oldPush=legacyRun(target,['hook','push','origin',f.remote],'a',input);assert.equal(oldPush.status,0,oldPush.stderr);
  await fail(target,['verify-pr','--branch','feat/v4','--sha',head],'a',/admission-aware.*authorization/i);
  await ok(target,['install']);
  const pushed=ownedGit(target,'push','origin','HEAD:refs/heads/feat/v4');assert.equal(pushed.status,0,pushed.stderr);
  await ok(target,['verify-pr','--branch','feat/v4','--sha',head]);
  await fail(target,['verify-pr','--branch','feat/v4','--sha','f'.repeat(40)],'a',/authorization/i);
  await ok(target,['release']);
  const stolen=f.spec(f.b,'TASK-61',['escape.lua'],[],{branch:'feat/test-1'});
  const recovered=legacyRun(f.b,['recover','--spec',stolen,'--evidence','Regression: old entry erases admission label'],'b');
  assert.equal(recovered.status,0,recovered.stderr);
  await fail(f.b,['check'],'b',/admission.*approval/i);
  const badHead=git(f.b,'rev-parse','HEAD');
  const oldAuthorization=legacyRun(f.b,['hook','push','origin',f.remote],'b',`HEAD ${badHead} refs/heads/feat/test-1 ${'0'.repeat(40)}\n`);
  assert.equal(oldAuthorization.status,0,oldAuthorization.stderr);
  await fail(f.b,['verify-pr','--branch','feat/test-1','--sha',badHead],'b',/admission.*approval/i);
});
