#!/usr/bin/env node
// Cooperative execution ownership. No dependencies and no checkout of the coordination branch.
import { spawnSync, spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, copyFileSync, existsSync, lstatSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID, createHash } from 'node:crypto';

const REF = 'refs/heads/coord/task-claims';
const argv = process.argv.slice(2), command = argv.shift();
const options = {}, rest = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--') { rest.push(...argv.slice(i + 1)); break; }
  if (argv[i].startsWith('--')) options[argv[i].slice(2)] = argv[++i];
  else rest.push(argv[i]);
}
const die = message => { throw new Error(message); };
function exec(bin, args, opts = {}) {
  const r = spawnSync(bin, args, { encoding: 'utf8', timeout: 30000, windowsHide: true, ...opts });
  if (r.error || r.status !== 0) die(`${bin} ${args[0]} failed: ${r.error?.message || r.stderr || r.stdout}`);
  return r.stdout.trim();
}
const git = (...args) => exec('git', args);
const jsonFile = path => JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''));
const need = key => options[key] || die(`--${key} is required`);
const now = () => Date.now();
const session = () => process.env.TASK_CLAIM_SESSION || die('TASK_CLAIM_SESSION is required for each executor session');
const branch = () => git('symbolic-ref', '--quiet', '--short', 'HEAD');
const receiptPath = () => resolve(git('rev-parse', '--git-path', 'task-claim-receipt.json'));
const receipt = () => { session(); const path = receiptPath(); if (!existsSync(path)) die('No task claim receipt: claim/adopt in an isolated worktree first; see docs/REMOTE_TASK_CLAIMS.md'); return jsonFile(path); };
const saveReceipt = r => writeFileSync(receiptPath(), JSON.stringify(r, null, 2) + '\n', { mode: 0o600 });
function taskID(value) {
  if (typeof value !== 'string' || !/^TASK-\d+(?:\.\d+)*$/i.test(value.trim())) die('Invalid Task ID');
  return 'TASK-' + value.trim().slice(5).split('.').map(p => p.replace(/^0+/, '') || '0').join('.');
}
function canonical(path) {
  if (typeof path !== 'string') die('scope path must be a string');
  const p = path.normalize('NFC').replaceAll('\\', '/').replace(/\/$/, '').toLowerCase();
  if (!p || p.startsWith('/') || /[:*?\x00-\x1f]/.test(p) || p.split('/').some(x => !x || /[. ]$/.test(x) || x === '.git' || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/.test(x))) die(`Invalid scope path: ${path}`);
  return p;
}
function scope(value) {
  if (!value || !Array.isArray(value.paths) || !value.paths.length || !Array.isArray(value.modules)) die('Explicit scope paths and modules array are required');
  const paths = [...new Set(value.paths.map(canonical))];
  const modules = [...new Set(value.modules.map(m => {
    if (typeof m !== 'string' || !/^[a-z][a-z0-9-]*$/.test(m)) die('Invalid shared module name');
    return m;
  }))];
  return { paths, modules };
}
const contains = (a, b) => a === b || b.startsWith(a + '/');
const related = (a, b) => contains(a.replaceAll('.', '/'), b.replaceAll('.', '/')) || contains(b.replaceAll('.', '/'), a.replaceAll('.', '/'));
function conflicts(a, b) {
  return (a.branch && a.branch === b.branch) || related(a.task, b.task) || a.scope.paths.some(p => b.scope.paths.some(q => contains(p, q) || contains(q, p))) || a.scope.modules.some(m => b.scope.modules.includes(m));
}
function lease(seconds) {
  const n = Number(seconds ?? 1800);
  if (!Number.isInteger(n) || n < 1 || n > 14400) die('leaseSeconds must be 1..14400');
  return n;
}
function spec() {
  const s = jsonFile(need('spec'));
  s.task = taskID(s.task);
  if (!s.agent || !s.session || s.session !== session() || !s.branch || !/^(feat|hotfix|release)\//.test(s.branch)) die('agent, unique matching session and work branch are required');
  git('check-ref-format', '--branch', s.branch);
  return { task: s.task, agent: s.agent, session: s.session, branch: s.branch, scope: scope(s.scope), leaseSeconds: lease(s.leaseSeconds) };
}
function owned(state, r, requireBranch = true) {
  const c = state.claims[r.task];
  if (r.session !== session()) die('Session mismatch: receipts must not be shared between executors');
  if (!c || c.status !== 'active' || c.session !== r.session || c.generation !== r.generation || c.branch !== r.branch) die('Ownership lost: released or superseded generation');
  if (Date.parse(c.expiresAt) <= now()) die('Ownership expired; recover with a new generation before work');
  if (requireBranch && branch() !== c.branch) die('Ownership branch mismatch');
  if (c.migrationGroup) {
    const group = approvedGroupClaim(state, c);
    if (requireBranch && absoluteIdentity(process.cwd()) !== absoluteIdentity(c.executionWorktree)) die('Ownership execution worktree mismatch');
    verifyGroupSources(group, c);
    checkConflicts(state, c, c.task, group.sources.map(source => source.reservation), group);
  }
  return c;
}
function checkConflicts(state, candidate, ignoreTask, ignoreReservation, group) {
  const ignored = new Set(Array.isArray(ignoreReservation) ? ignoreReservation : [ignoreReservation]);
  for (const c of Object.values(state.claims)) {
    if (group && c.task !== ignoreTask && c.migrationGroup === group.id && c.status === 'active' && Date.parse(c.expiresAt) > now()) die('Migration group stages are strictly serial');
    if (c.task !== ignoreTask && c.status === 'active' && Date.parse(c.expiresAt) > now() && conflicts(candidate, c)) die(`Conflict with ${c.task} (${c.agent}/${c.session})`);
  }
  for (const r of state.migration.reservations) {
    if (r.status !== 'unknown' || ignored.has(r.id) || !conflicts(candidate, r)) continue;
    // These original records remain byte-for-byte in the audit. A Backlog
    // management row is not execution ownership; only a reconciled adoption
    // may use this provenance-backed distinction. Ordinary claims stay closed.
    if (group && (isTaskTracking(state, r) || handedOffSource(state, r.id))) continue;
    die(`Conflict with unresolved migration reservation ${r.id}`);
  }
}

const digest = value => createHash('sha256').update(value).digest('hex');
function absoluteIdentity(path) {
  const absolute = resolve(path);
  if (existsSync(absolute)) return realpathSync.native(absolute);
  if (dirname(absolute) === absolute) die('Path has no existing root');
  return join(absoluteIdentity(dirname(absolute)), basename(absolute));
}
function sourceSnapshot(path) {
  if (lstatSync(resolve(path)).isSymbolicLink()) die('Snapshot requires a real worktree root');
  const worktree = absoluteIdentity(path);
  // Hooks inherit the committing index/worktree. Foreign reads must use that
  // source's own Git context; keep the caller and remote authentication intact.
  const env = { ...process.env };
  const local = new Set(git('rev-parse', '--local-env-vars').split(/\r?\n/).map(key => key.toUpperCase()));
  for (const key of Object.keys(env)) if (local.has(key.toUpperCase())) delete env[key];
  const g = (...args) => exec('git', ['--no-optional-locks', '-C', worktree, ...args], { env });
  if (absoluteIdentity(g('rev-parse', '--show-toplevel')) !== worktree) die('Snapshot requires a real worktree root');
  const paths = [...new Set([...g('diff', '--name-only', '--no-renames', '-z', 'HEAD').split('\0'),
    ...g('ls-files', '--others', '--exclude-standard', '-z').split('\0')].filter(Boolean))].sort();
  const dirty = paths.map(path => {
    canonical(path);
    const file = join(worktree, path);
    if (existsSync(file) && (!lstatSync(file).isFile() || lstatSync(file).isSymbolicLink())) die('Snapshot contains an unsupported file alias');
    return { path, sha256: existsSync(file) ? digest(readFileSync(file)) : null };
  });
  return { worktree, remote: g('remote', 'get-url', 'origin'), head: g('rev-parse', 'HEAD'), branch: g('symbolic-ref', '--quiet', '--short', 'HEAD'),
    indexSha256: digest(g('ls-files', '--stage', '-z')), dirty };
}
function verifySnapshot(expected) {
  if (!expected?.worktree || JSON.stringify(sourceSnapshot(expected.worktree)) !== JSON.stringify(expected)) die('Source snapshot fingerprint drift; stop and reconfirm delivery');
}
function isTaskTracking(state, r) {
  return r.branch === null && r.id === `backlog-${r.task}`
    && r.reason === 'In Progress is not execution ownership; exact executor and scope require acknowledgement'
    && state.migration.inventory?.tasks?.some(t => taskID(t.id) === r.task)
    && state.migration.inventory.reservations.some(original => original.id === r.id && original.branch === null);
}
function verifyGroupSources(group, claim) {
  for (const source of group.sources) {
    if (source.role === 'executor-target' && source.task === claim?.task && source.snapshot.branch === claim.branch
      && source.snapshot.worktree === claim.executionWorktree) continue;
    verifySnapshot(source.handoff?.snapshot || source.snapshot);
  }
}
function approvedGroupClaim(state, claim) {
  const group = state.migration.reconciliations?.[claim.migrationGroup];
  const stage = group?.stages[group.cursor];
  if (!group || !stage || group.executorSession !== claim.session || stage.id !== claim.migrationStage
    || stage.task !== claim.task || stage.branch !== claim.branch || JSON.stringify(stage.scope) !== JSON.stringify(claim.scope)) die('Migration stage approval lost');
  return group;
}
function handedOffSource(state, reservation) {
  for (const group of Object.values(state.migration.reconciliations || {})) {
    const source = group.sources.find(s => s.reservation === reservation && s.handoff);
    if (source) { verifySnapshot(source.handoff.snapshot); return true; }
  }
  return false;
}
function reconciliation(state, raw) {
  if (!raw || !/^[a-z][a-z0-9-]*$/.test(raw.id) || !raw.executorSession || !raw.evidence
    || !Array.isArray(raw.sources) || !raw.sources.length || !Array.isArray(raw.stages) || !raw.stages.length) die('Explicit reconciliation identity, executor, evidence, sources and stages are required');
  if (state.migration.status !== 'paused') die('Reconciliation is only for paused migration');
  const groups = state.migration.reconciliations || {};
  if (groups[raw.id]) die('Reconciliation group already exists; do not overwrite its audit');
  const seen = new Set();
  const sources = raw.sources.map(source => {
    const original = state.migration.reservations.find(r => r.id === source.reservation && r.status === 'unknown');
    const task = taskID(source.task);
    if (!original || task === 'TASK-0' || seen.has(original.id) || !['parked-readonly', 'executor-target'].includes(source.role)
      || !original.branch || original.branch !== source.snapshot?.branch
      || !['TASK-0', task].includes(original.task) || !Array.isArray(source.commits)) die('Invalid or duplicate confirmed source mapping');
    if (original.worktree && absoluteIdentity(original.worktree) !== source.snapshot.worktree) die('Source worktree differs from legacy reservation');
    if (source.snapshot.remote !== git('remote', 'get-url', 'origin')) die('Source belongs to a different remote');
    if (Object.values(groups).some(g => g.sources.some(s => s.reservation === original.id))) die('Source already belongs to a reconciliation group');
    for (const c of Object.values(state.claims)) {
      if (c.task !== state.migration.bootstrapTask && c.status === 'active' && Date.parse(c.expiresAt) > now()
        && conflicts({ task, branch: original.branch, scope: original.scope }, c)) die('Cannot reconcile across an active claim');
    }
    verifySnapshot(source.snapshot); seen.add(original.id);
    const committedPaths = new Set();
    for (const commit of source.commits) {
      if (!/^[a-f0-9]{40}$/.test(commit)) die('Delivery commits require full SHA identities');
      exec('git', ['-C', source.snapshot.worktree, 'merge-base', '--is-ancestor', commit, source.snapshot.head]);
      const parents = exec('git', ['-C', source.snapshot.worktree, 'show', '-s', '--format=%P', commit]);
      if (!parents || parents.split(' ').length !== 1) die('List explicit single-parent delivery commits rather than inherited ancestry');
      for (const path of exec('git', ['-C', source.snapshot.worktree, 'diff-tree', '--no-commit-id', '--name-only', '--no-renames', '-r', '-z', commit]).split('\0').filter(Boolean)) committedPaths.add(canonical(path));
    }
    return { reservation: original.id, task, role: source.role, snapshot: structuredClone(source.snapshot), commits: [...source.commits],
      committedPaths: [...committedPaths].sort(), original: structuredClone(original) };
  });
  const stageIds = new Set();
  const stages = raw.stages.map((stage, index) => {
    if (!/^[a-z][a-z0-9-]*$/.test(stage.id) || stageIds.has(stage.id) || !Array.isArray(stage.sources) || !stage.sources.length
      || !Array.isArray(stage.extraPaths)) die('Explicit unique stage and bounded sources/extraPaths required');
    stageIds.add(stage.id); const task = taskID(stage.task); git('check-ref-format', '--branch', stage.branch);
    if (task === 'TASK-0') die('Stage requires the actual task identity');
    if (!stage.branch.startsWith('feat/')) die('Migration execution requires a feature branch');
    const required = new Set();
    for (const id of stage.sources) {
      const source = sources.find(s => s.reservation === id); if (!source) die('Stage references an unconfirmed source');
      for (const path of [...source.committedPaths, ...source.snapshot.dirty.map(d => canonical(d.path))]) required.add(path);
    }
    for (const extra of stage.extraPaths) {
      if (!extra.reason) die('Extra delivery paths require an explicit purpose');
      const path = canonical(extra.path);
      if (sources.some(s => existsSync(join(s.snapshot.worktree, path)) && lstatSync(join(s.snapshot.worktree, path)).isDirectory())) die('Extra paths must name files, not generic directories');
      required.add(path);
    }
    const declared = scope(stage.scope);
    if (declared.paths.length !== required.size || declared.paths.some(p => !required.has(p))) die('Stage scope must include the complete explicit commit/dirty/extra file inventory');
    for (const source of sources) if (source.snapshot.branch === stage.branch
      && (source.role !== 'executor-target' || source.task !== task)) die('Parked read-only source branch cannot become an execution branch');
    if (index > 0 && raw.stages[index - 1].branch === stage.branch
      && scope(raw.stages[index - 1].scope).paths.some(p => !declared.paths.includes(p))) die('Retained execution branch scope must preserve prior stage delivery');
    return { id: stage.id, task, branch: stage.branch, scope: declared, sources: [...stage.sources] };
  });
  return { id: raw.id, executorSession: raw.executorSession, evidence: raw.evidence, sources, stages, cursor: 0,
    confirmedBy: session(), confirmedAt: new Date().toISOString() };
}

function extendReconciliation(state, raw, evidence) {
  const previous = state.migration.reconciliations?.[raw.id];
  if (!previous || previous.cursor >= previous.stages.length) die('Extension requires an existing unfinished group');
  if (previous.sources.some(source => source.role !== 'parked-readonly' || source.handoff)) die('Extensions require parked-readonly source groups');
  if (Object.values(state.claims).some(c => c.migrationGroup === raw.id && c.status === 'active' && Date.parse(c.expiresAt) > now())) die('Group must be idle before a coordinator extends scope');
  const groups = { ...state.migration.reconciliations }; delete groups[raw.id];
  const next = reconciliation({ ...state, migration: { ...state.migration, reconciliations: groups } }, raw);
  if (next.executorSession !== previous.executorSession || JSON.stringify(next.sources) !== JSON.stringify(previous.sources)
    || next.stages.length !== previous.stages.length) die('Extension cannot change executor, source identity or stage sequence');
  let added = 0;
  for (let i = 0; i < previous.stages.length; i++) {
    const before = previous.stages[i], after = next.stages[i];
    if (i < previous.cursor) {
      if (JSON.stringify(before) !== JSON.stringify(after)) die('Completed stages cannot change');
      continue;
    }
    if (before.id !== after.id || before.task !== after.task || before.branch !== after.branch
      || JSON.stringify(before.sources) !== JSON.stringify(after.sources)
      || JSON.stringify(before.scope.modules) !== JSON.stringify(after.scope.modules)
      || before.scope.paths.some(path => !after.scope.paths.includes(path))) die('Remaining stages permit additive exact files only');
    added += after.scope.paths.filter(path => !before.scope.paths.includes(path)).length;
  }
  if (!added) die('Extension must add an explicitly justified file');
  return { ...previous, stages: next.stages, amendments: [...(previous.amendments || []), {
    at: new Date().toISOString(), confirmedBy: session(), evidence, previousManifestSha256: previous.manifestSha256,
    previousStages: previous.stages, cursor: previous.cursor,
  }] };
}

// Each process uses its own disposable object database: no shared FETCH_HEAD/index locks.
let temp;
function remoteClient() {
  const remote = git('remote', 'get-url', 'origin');
  temp = mkdtempSync(join(tmpdir(), 'task-claim-git-'));
  exec('git', ['init', '--bare', temp]);
  const g = (...args) => exec('git', ['--git-dir', temp, '-c', 'core.hooksPath=' + join(temp, 'no-hooks'), ...args]);
  function read() {
    // exit 2 alone means a reachable remote with no matching ref; every other failure closes the gate.
    const ls = spawnSync('git', ['ls-remote', '--exit-code', remote, REF], { encoding: 'utf8', timeout: 30000, windowsHide: true });
    if (ls.status === 2) return { sha: null, state: null };
    if (ls.error || ls.status !== 0) die(`Remote unreachable: ${ls.error?.message || ls.stderr}`);
    g('fetch', '--no-tags', remote, REF);
    const sha = g('rev-parse', 'FETCH_HEAD');
    const state = JSON.parse(g('show', `${sha}:claims.json`));
    if (state.schema !== 1 || !Number.isSafeInteger(state.generation) || state.generation < 0 || !state.claims || !state.migration || !Array.isArray(state.migration.reservations) || !['paused', 'open'].includes(state.migration.status)) die('Unsupported or corrupt coordination state');
    for (const [id, c] of Object.entries(state.claims)) {
      if (c.task !== id || taskID(id) !== id || !Number.isSafeInteger(c.generation) || c.generation < 1 || c.generation > state.generation || !c.session || !c.agent || !c.branch || !['active', 'released'].includes(c.status) || !Number.isFinite(Date.parse(c.expiresAt))) die('Corrupt claim; gate closed');
      scope(c.scope); lease(c.leaseSeconds);
    }
    return { sha, state };
  }
  function mutate(change) {
    let snapshot = read();
    for (let attempt = 0; attempt < 6; attempt++) {
      const state = snapshot.state ? structuredClone(snapshot.state) : null;
      const updated = change(state); // MUST revalidate ownership, expiry, conflicts and migration on every CAS retry.
      const object = exec('git', ['--git-dir', temp, 'hash-object', '-w', '--stdin'], { input: JSON.stringify(updated) + '\n' });
      const tree = exec('git', ['--git-dir', temp, 'mktree'], { input: `100644 blob ${object}\tclaims.json\n` });
      const env = { ...process.env, GIT_AUTHOR_NAME: 'Task Claim Protocol', GIT_AUTHOR_EMAIL: 'task-claim@invalid', GIT_COMMITTER_NAME: 'Task Claim Protocol', GIT_COMMITTER_EMAIL: 'task-claim@invalid' };
      const commit = exec('git', ['--git-dir', temp, 'commit-tree', tree, ...(snapshot.sha ? ['-p', snapshot.sha] : []), '-m', `chore(claim): ${command}`], { env });
      // Never force, never merge rejected state and never reuse a rejected commit on a new parent.
      const push = spawnSync('git', ['--git-dir', temp, '-c', 'core.hooksPath=' + join(temp, 'no-hooks'), 'push', remote, `${commit}:${REF}`], { encoding: 'utf8', timeout: 30000, windowsHide: true });
      if (!push.error && push.status === 0) return updated;
      const latest = read();
      if (latest.sha === snapshot.sha) die(`Coordination push rejected: ${push.error?.message || push.stderr}`);
      snapshot = latest;
    }
    die('CAS contention limit reached; no claim success reported; read remote and retry explicitly');
  }
  return { read, mutate, remote };
}
function requireState(s) { if (!s) die('Coordination branch uninitialized; do not begin work'); return s; }
function changedPaths(mode, input = '', claim) {
  if (mode === 'commit') return git('diff', '--cached', '--name-only', '--no-renames', '-z', claim?.base || 'HEAD').split('\0').filter(Boolean);
  if (mode === 'push') {
    const r = claim || receipt();
    const lines = input.trim().split('\n').filter(Boolean);
    if (!lines.length) die('pre-push requires actual pushed ref input');
    const paths = [];
    for (const line of lines) {
      const [localRef, sha, remoteRef] = line.trim().split(/\s+/);
      if (![ `refs/heads/${r.branch}`, 'HEAD' ].includes(localRef) || remoteRef !== `refs/heads/${r.branch}` || /^0+$/.test(sha) || sha !== git('rev-parse', 'HEAD')) die('Push gate permits only the owned work branch HEAD; no deletion or integration branch push');
      paths.push(...git('diff', '--name-only', '--no-renames', '-z', r.base, sha).split('\0').filter(Boolean));
    }
    return paths;
  }
  return [...git('diff', '--name-only', '--no-renames', '-z', 'HEAD').split('\0'), ...git('ls-files', '--others', '--exclude-standard', '-z').split('\0')].filter(Boolean);
}
function checkPaths(c, paths) {
  for (const path of paths) {
    const p = canonical(path);
    if (!c.scope.paths.some(root => c.migrationGroup ? root === p : contains(root, p))) die(`Out of scope: ${path}; expand remotely before modifying it`);
    // Symlink aliases can otherwise escape declared scope. Junctions/symlinks are not controlled write targets.
    let target = process.cwd();
    for (const part of path.replaceAll('\\', '/').split('/')) {
      target = join(target, part);
      if (existsSync(target) && lstatSync(target).isSymbolicLink()) die(`Symlink scope is unsupported: ${path}`);
    }
  }
}
function createWorktree(r, target) {
  if (r.migrationGroup && absoluteIdentity(target) !== absoluteIdentity(r.executionWorktree)) die('Migration execution worktree must match its approved target');
  if (existsSync(target)) die('Target exists; refuse to alter existing worktree');
  const ref = spawnSync('git', ['show-ref', '--verify', '--quiet', `refs/heads/${r.branch}`]);
  if (ref.status === 0) git('worktree', 'add', target, r.branch);
  else if (ref.status === 1) git('worktree', 'add', '-b', r.branch, target, r.base);
  else die('Cannot inspect target branch');
  if (absoluteIdentity(exec('git', ['-C', target, 'rev-parse', '--show-toplevel'])) !== absoluteIdentity(target)
    || exec('git', ['-C', target, 'symbolic-ref', '--quiet', '--short', 'HEAD']) !== r.branch) die('Created worktree does not match the approved target and branch');
  const path = exec('git', ['-C', target, 'rev-parse', '--git-path', 'task-claim-receipt.json']);
  writeFileSync(resolve(target, path), JSON.stringify(r, null, 2) + '\n', { mode: 0o600 });
  return { worktree: target, task: r.task };
}
function install() {
  const common = resolve(git('rev-parse', '--git-common-dir'));
  const hooks = join(common, 'task-claim-hooks');
  const existing = spawnSync('git', ['config', '--get', 'core.hooksPath'], { encoding: 'utf8' }).stdout.trim();
  if (existing && resolve(existing) !== hooks) die('Existing hooksPath detected; preserve and integrate those hooks manually before install');
  if (!existing) {
    const native = join(common, 'hooks');
    if (['pre-commit', 'pre-push', 'pre-merge-commit', 'prepare-commit-msg', 'pre-rebase'].some(name => existsSync(join(native, name)))) die('Existing Git hooks detected; install refuses to overwrite them');
  }
  mkdirSync(hooks, { recursive: true });
  const runtime = join(hooks, 'runtime.mjs');
  copyFileSync(fileURLToPath(import.meta.url), runtime);
  for (const [name, phase] of [['pre-commit', 'commit'], ['pre-push', 'push'], ['pre-merge-commit', 'ownership'], ['prepare-commit-msg', 'ownership'], ['pre-rebase', 'ownership']]) {
    writeFileSync(join(hooks, name), `#!/bin/sh\nexec node "$(dirname "$0")/runtime.mjs" hook ${phase} "$@"\n`, { mode: 0o755 });
  }
  git('config', '--local', 'core.hooksPath', hooks.replaceAll('\\', '/'));
  return { installed: hooks, sharedAcrossLocalWorktrees: true };
}
async function runGuarded(client, r) {
  if (!rest.length) die('run requires -- executable arguments');
  let c = owned(requireState(client.read().state), r);
  checkPaths(c, changedPaths());
  // Renew before launching; an offline or fenced owner cannot even start the child.
  client.mutate(s => { c = owned(requireState(s), r); c.expiresAt = new Date(now() + c.leaseSeconds * 1000).toISOString(); return s; });
  const child = spawn(rest[0], rest.slice(1), { stdio: 'inherit', windowsHide: true, detached: process.platform !== 'win32' });
  let lost;
  const kill = () => {
    if (process.platform === 'win32') spawnSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], { windowsHide: true });
    else { try { process.kill(-child.pid, 'SIGKILL'); } catch { /* already exited */ } }
  };
  const timer = setInterval(() => {
    try { client.mutate(s => { const current = owned(requireState(s), r); current.expiresAt = new Date(now() + current.leaseSeconds * 1000).toISOString(); return s; }); }
    catch (e) { lost = e; clearInterval(timer); kill(); }
  }, Math.max(250, Math.min(60000, c.leaseSeconds * 1000 / 3)));
  const interrupted = () => { lost = new Error('Controlled executor interrupted'); kill(); };
  process.once('SIGINT', interrupted); process.once('SIGTERM', interrupted);
  const code = await new Promise((res, rej) => { child.on('error', rej); child.on('close', res); }).finally(() => {
    clearInterval(timer); process.removeListener('SIGINT', interrupted); process.removeListener('SIGTERM', interrupted);
  });
  if (lost) throw lost;
  if (code !== 0) die(`Controlled command failed (${code})`);
  c = owned(requireState(client.read().state), r); checkPaths(c, changedPaths());
  return { checked: true, task: c.task, generation: c.generation };
}
async function main() {
  if (command === 'session') return { session: randomUUID() };
  if (command === 'migration-snapshot') return sourceSnapshot(need('path'));
  if (command === 'help' || !command) return { usage: 'TASK_CLAIM_SESSION=<unique ID>; node scripts/remote-task-claim.mjs <init|claim|adopt|recover|renew|check|expand|release|list|migration-snapshot|migration-reconcile|migration-open|install|worktree|run|hook|integrate|session> [--spec file] [--inventory file] [--evidence text]. Reconciled adoption: --group ID --stage ID; serial completion: release --stage-complete yes --evidence text. See docs/REMOTE_TASK_CLAIMS.md' };
  const client = remoteClient();
  if (command === 'list') {
    const s = requireState(client.read().state);
    return { active: Object.values(s.claims).filter(c => c.status === 'active' && Date.parse(c.expiresAt) > now()), expired: Object.values(s.claims).filter(c => c.status === 'active' && Date.parse(c.expiresAt) <= now()), released: Object.values(s.claims).filter(c => c.status === 'released'), migration: s.migration, generation: s.generation };
  }
  if (command === 'verify-pr') {
    const s = requireState(client.read().state), sha = need('sha'), name = need('branch');
    const matches = Object.values(s.claims).filter(c => c.status === 'active' && Date.parse(c.expiresAt) > now() && c.branch === name && c.authorizedSha === sha);
    if (matches.length !== 1) die('PR has no unique live ownership authorization for its exact head SHA; adopt/renew and push through the gate');
    if (matches[0].migrationGroup) approvedGroupClaim(s, matches[0]);
    return { checked: true, task: matches[0].task, generation: matches[0].generation, sha };
  }
  if (['init', 'claim', 'adopt', 'recover'].includes(command)) {
    const candidate = spec();
    const target = options.path ? resolve(options.path) : null;
    if (target && existsSync(target)) die('Target exists; refuse to alter existing worktree');
    if (!target && command !== 'init' && existsSync(receiptPath())) {
      const previous = jsonFile(receiptPath());
      const s = client.read().state, old = s?.claims[previous.task];
      if (old?.status === 'active' && Date.parse(old.expiresAt) > now() && old.generation === previous.generation) die('Worktree already has an active receipt; use a separate worktree');
    }
    const state = client.mutate(original => {
      let s = original;
      if (command === 'init') {
        if (s) die('Coordination branch already initialized');
        const inventory = jsonFile(need('inventory'));
        if (typeof inventory.externalUnknown !== 'boolean' || !Array.isArray(inventory.reservations)) die('Inventory must explicitly record externalUnknown and reservations');
        const reservations = inventory.reservations.map(r => ({ ...r, task: taskID(r.task), scope: scope(r.scope), status: 'unknown' }));
        if (new Set(reservations.map(r => r.id)).size !== reservations.length || reservations.some(r => !r.id)) die('Invalid migration reservation identities');
        s = { schema: 1, generation: 0, claims: {}, migration: { status: 'paused', externalUnknown: inventory.externalUnknown, bootstrapTask: candidate.task, reservations, inventory, initializedAt: new Date().toISOString() } };
        // Bootstrap is narrow and explicit; no legacy reservation may intersect its scope.
      } else requireState(s);
      if (command === 'claim' && s.migration.status !== 'open') die('Migration paused: adopt existing work; no fresh parallel claims');
      const old = s.claims[candidate.task];
      if (old?.migrationGroup && (command !== 'adopt' || options.group !== old.migrationGroup)) die('Reconciled task must resume through its designated group and approved stage');
      if (old?.status === 'active' && Date.parse(old.expiresAt) > now()) die(`Conflict: ${candidate.task} already actively owned`);
      if (command === 'claim' && old?.status === 'active') die('Expired claim exists; use recover with evidence and a new generation');
      if (command === 'recover' && (!old || (old.status === 'active' && Date.parse(old.expiresAt) > now()))) die('recover requires an expired or released lease');
      if (command === 'recover') need('evidence');
      let reservation;
      if (command === 'adopt') {
        need('evidence');
        if (options.group) {
          const group = s.migration.reconciliations?.[options.group], stage = group?.stages[group.cursor];
          if (!group || group.executorSession !== session()) die('Only the designated reconciliation executor session may adopt');
          if (stage?.id !== need('stage') || candidate.task !== stage.task || candidate.branch !== stage.branch
            || JSON.stringify(candidate.scope) !== JSON.stringify(stage.scope)) die('Adoption must match the next approved stage task, branch and full scope');
          const executionWorktree = absoluteIdentity(target || process.cwd());
          if (group.sources.some(source => source.role === 'parked-readonly' && source.snapshot.worktree === executionWorktree)) die('Parked read-only source cannot be an execution worktree');
          if (!target && branch() !== candidate.branch) die('Adopt in the approved execution branch or use --path for a new worktree');
          candidate.migrationGroup = group.id; candidate.migrationStage = stage.id; candidate.executionWorktree = executionWorktree;
          const retainedTarget = old?.migrationGroup === group.id && old.session === candidate.session
            && old.branch === candidate.branch && old.executionWorktree === executionWorktree;
          verifyGroupSources(group, retainedTarget ? candidate : undefined);
          checkConflicts(s, candidate, undefined, group.sources.map(source => source.reservation), group);
        } else {
          reservation = s.migration.reservations.find(r => r.id === need('reservation') && r.status === 'unknown');
          if (!reservation || reservation.task !== candidate.task || (reservation.branch && reservation.branch !== candidate.branch)) die('Unresolved reservation must match adopted task and branch');
          if (!reservation.scope.paths.every(p => candidate.scope.paths.some(q => contains(q, p))) || !reservation.scope.modules.every(m => candidate.scope.modules.includes(m))) die('Adoption scope must preserve the entire legacy reservation');
        }
      }
      if (command === 'init') {
        s.migration.bootstrapEvidence = need('evidence');
        s.migration.bootstrapOverlaps = s.migration.reservations.filter(r => conflicts(candidate, r)).map(r => r.id);
        // The one installation owner exists before legacy executors can adopt. They remain quarantined,
        // never silently treated as free, and cannot obtain conflicting protocol rights.
      } else {
        const coordinatorRecovery = command === 'recover' && s.migration.status === 'paused' && candidate.task === s.migration.bootstrapTask;
        if (coordinatorRecovery && JSON.stringify(candidate.scope) !== JSON.stringify(old.scope)) die('Coordinator recovery must preserve the original bootstrap scope');
        if (!candidate.migrationGroup) checkConflicts(s, candidate, undefined, coordinatorRecovery ? s.migration.bootstrapOverlaps : reservation?.id);
      }
      const generation = ++s.generation, at = now();
      const targetTip = spawnSync('git', ['rev-parse', '--verify', `refs/heads/${candidate.branch}`], { encoding: 'utf8' });
      const upstreamTip = spawnSync('git', ['rev-parse', '--verify', 'origin/develop'], { encoding: 'utf8' });
      // An existing work branch keeps its own fork point. A NEW branch starts from fetched develop,
      // even when the controller/parent checkout is old or contains unrelated independent work.
      const workTip = targetTip.status === 0 ? targetTip.stdout.trim() : upstreamTip.status === 0 ? upstreamTip.stdout.trim() : git('rev-parse', 'HEAD');
      const base = upstreamTip.status === 0 ? git('merge-base', workTip, upstreamTip.stdout.trim()) : workTip;
      s.claims[candidate.task] = { ...candidate, generation, status: 'active', claimedAt: new Date(at).toISOString(), expiresAt: new Date(at + candidate.leaseSeconds * 1000).toISOString(), base, evidence: options.evidence || null };
      if (reservation) { reservation.status = 'adopted'; reservation.evidence = options.evidence; reservation.generation = generation; }
      return s;
    });
    const c = state.claims[candidate.task];
    // A successful push followed by a failed confirmation is not reported as success. Lease remains recoverable.
    const r = { ...c, remote: client.remote };
    owned(requireState(client.read().state), r, false);
    if (target) {
      createWorktree(r, target); // parent receipt is never overwritten; child has its own session and branch.
      owned(requireState(client.read().state), r, false);
    } else saveReceipt(r);
    return target ? { ...c, worktree: target } : c;
  }
  const r = receipt();
  if (r.remote !== client.remote) die('Remote differs from claim receipt');
  if (command === 'migration-reconcile') {
    const bytes = readFileSync(need('manifest'));
    const manifest = JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
    const state = client.mutate(s => {
      requireState(s); const c = owned(s, r);
      if (c.task !== s.migration.bootstrapTask) die('Only the active migration coordinator may reconcile');
      if (options.extend && options.extend !== 'yes') die('Use --extend yes explicitly');
      const group = options.extend === 'yes' ? extendReconciliation(s, manifest, need('evidence')) : reconciliation(s, manifest);
      group.manifestSha256 = digest(bytes); group.generation = ++s.generation;
      s.migration.reconciliations ||= {}; s.migration.reconciliations[group.id] = group;
      return s;
    });
    const group = state.migration.reconciliations[manifest.id]; verifyGroupSources(group);
    return { reconciled: group.id, generation: group.generation, sourceReservations: group.sources.map(source => source.reservation),
      migration: state.migration.status, externalUnknown: state.migration.externalUnknown };
  }
  if (command === 'check' || command === 'hook') {
    const c = owned(requireState(client.read().state), r);
    if (command === 'hook') {
      let input = rest[0] === 'push' ? readFileSync(0, 'utf8') : '';
      if (!['commit', 'push', 'ownership'].includes(rest[0])) die('Unknown hook phase');
      if (rest[0] === 'push' && !input.trim()) {
        const sha = git('rev-parse', 'HEAD');
        const remoteHead = git('ls-remote', '--exit-code', client.remote, `refs/heads/${c.branch}`).split(/\s+/)[0];
        if (remoteHead !== sha) die('No pushed refs and remote owned branch differs from HEAD');
        // A safe no-op push also authorizes an adopted, already-published exact head.
        input = `HEAD ${sha} refs/heads/${c.branch} ${sha}\n`;
      }
      if (rest[0] !== 'ownership') checkPaths(c, changedPaths(rest[0], input, c));
      if (rest[0] === 'push') {
        if (rest[2] !== client.remote) die('Push destination differs from the claimed origin');
        const sha = git('rev-parse', 'HEAD');
        client.mutate(s => {
          const current = owned(requireState(s), r);
          checkPaths(current, changedPaths('push', input, current));
          current.authorizedSha = sha;
          return s;
        });
      }
    }
    if (command === 'check' && options.paths === 'dirty') checkPaths(c, changedPaths());
    return { checked: true, task: c.task, generation: c.generation, expiresAt: c.expiresAt };
  }
  if (['renew', 'release', 'expand', 'sync-base', 'migration-open', 'migration-resolve'].includes(command)) {
    let newBase, pendingMerge = false;
    if (command === 'sync-base') {
      newBase = need('base');
      const remoteBase = git('ls-remote', '--exit-code', client.remote, 'refs/heads/develop').split(/\s+/)[0];
      const mergeHead = resolve(git('rev-parse', '--git-path', 'MERGE_HEAD'));
      pendingMerge = existsSync(mergeHead) && readFileSync(mergeHead, 'utf8').trim() === newBase;
      if (newBase !== remoteBase || (!pendingMerge && git('merge-base', 'HEAD', newBase) !== newBase)) die('sync-base requires the current remote develop SHA merged or staged as the sole MERGE_HEAD');
      if (pendingMerge && git('diff', '--name-only', '--diff-filter=U')) die('Resolve and stage all merge conflicts before sync-base');
    }
    const state = client.mutate(s => {
      requireState(s); const c = owned(s, r);
      if (command === 'renew') c.expiresAt = new Date(now() + c.leaseSeconds * 1000).toISOString();
      if (command === 'release') {
        if (options['stage-complete']) {
          if (options['stage-complete'] !== 'yes' || !c.migrationGroup) die('Stage completion requires a reconciled claim and --stage-complete yes');
          need('evidence'); const group = approvedGroupClaim(s, c);
          for (const source of group.sources) if (source.role === 'executor-target' && source.task === c.task
            && source.snapshot.worktree === c.executionWorktree && source.snapshot.branch === c.branch) {
            source.handoff = { snapshot: sourceSnapshot(c.executionWorktree), evidence: options.evidence,
              session: c.session, generation: c.generation, at: new Date().toISOString() };
          }
          group.completed ||= []; group.completed.push({ stage: c.migrationStage, session: c.session, generation: c.generation,
            evidence: options.evidence, at: new Date().toISOString() }); group.cursor++;
        }
        c.status = 'released'; c.releasedAt = new Date().toISOString();
      }
      if (command === 'sync-base') {
        git('merge-base', '--is-ancestor', c.base, newBase);
        const diffArgs = pendingMerge ? ['--cached', newBase] : [newBase, 'HEAD'];
        checkPaths(c, git('diff', '--name-only', '--no-renames', '-z', ...diffArgs).split('\0').filter(Boolean));
        c.base = newBase;
      }
      if (command === 'expand') {
        if (c.migrationGroup) die('Reconciled stages use the complete coordinator-approved scope; do not expand past its proof');
        const expanded = scope(jsonFile(need('scope')));
        if (!c.scope.paths.every(p => expanded.paths.some(q => contains(q, p))) || !c.scope.modules.every(m => expanded.modules.includes(m))) die('expand cannot silently shrink scope');
        checkConflicts(s, { ...c, scope: expanded }, c.task); c.scope = expanded;
      }
      if (command === 'migration-resolve') {
        need('evidence');
        if (c.task !== s.migration.bootstrapTask) die('Only bootstrap coordinator may resolve migration');
        if (options.reservation) {
          const legacy = s.migration.reservations.find(x => x.id === options.reservation && x.status === 'unknown');
          if (!legacy) die('Unknown or resolved reservation');
          legacy.status = 'resolved'; legacy.evidence = options.evidence;
        } else if (options['external-reviewed'] === 'yes') {
          s.migration.externalUnknown = false; s.migration.externalEvidence = options.evidence;
        } else die('Specify --reservation or --external-reviewed yes with actual executor stop/review evidence');
      }
      if (command === 'migration-open') {
        need('evidence');
        if (c.task !== s.migration.bootstrapTask) die('Only bootstrap coordinator may open migration');
        if (s.migration.externalUnknown || s.migration.reservations.some(x => x.status === 'unknown')) die('Unresolved migration or unknown external executors; keep paused');
        s.migration.status = 'open'; s.migration.evidence = options.evidence;
      }
      return s;
    });
    if (command === 'expand' || command === 'sync-base') saveReceipt({ ...r, scope: state.claims[r.task].scope, base: state.claims[r.task].base });
    return state.claims[r.task];
  }
  const c = owned(requireState(client.read().state), r, command !== 'worktree');
  if (command === 'install') return install();
  if (command === 'run') return runGuarded(client, r);
  if (command === 'worktree') {
    const target = resolve(need('path'));
    return createWorktree(r, target);
  }
  if (command === 'integrate') {
    const sha = need('sha'), pr = need('pr');
    const info = JSON.parse(exec('gh', ['pr', 'view', pr, '--json', 'headRefOid,headRefName,baseRefName,statusCheckRollup,state']));
    if (info.state !== 'OPEN' || info.headRefOid !== sha || info.headRefName !== c.branch || info.baseRefName !== 'develop' || git('rev-parse', 'HEAD') !== sha || c.authorizedSha !== sha) die('PR must match exact owned, push-authorized branch/HEAD and target develop');
    if (!info.statusCheckRollup.length || info.statusCheckRollup.some(x => (x.conclusion || x.state) !== 'SUCCESS')) die('Every current-SHA CI check must succeed before integration');
    checkPaths(c, git('diff', '--name-only', '--no-renames', '-z', c.base, sha).split('\0').filter(Boolean));
    client.mutate(s => { const current = owned(requireState(s), r); current.expiresAt = new Date(now() + current.leaseSeconds * 1000).toISOString(); return s; });
    owned(requireState(client.read().state), r);
    exec('gh', ['pr', 'merge', pr, '--squash', '--match-head-commit', sha]);
    return { integrated: pr, head: sha };
  }
  die(`Unknown command: ${command}`);
}
try { const result = await main(); process.stdout.write(JSON.stringify(result, null, 2) + '\n'); }
catch (e) { process.stderr.write(`Task claim gate: ${e.message}\n`); process.exitCode = 1; }
finally {
  if (temp && dirname(resolve(temp)) === resolve(tmpdir()) && basename(temp).startsWith('task-claim-git-')) rmSync(temp, { recursive: true, force: true });
}
