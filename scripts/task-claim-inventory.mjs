// Read-only snapshot. Feed Backlog CLI JSON; never infer that a clean/stale branch has no executor.
import { spawnSync } from 'node:child_process';
import { readFileSync, existsSync, lstatSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';

function git(...args) {
  const r = spawnSync('git', ['-c', 'core.quotepath=false', ...args], { encoding: 'utf8', timeout: 30000 });
  if (r.status !== 0) throw new Error(r.stderr || 'Git inventory failed');
  return r.stdout.trim();
}
const tasksFile = process.argv[2];
if (!tasksFile) throw new Error('Usage: node scripts/task-claim-inventory.mjs <backlog task list --status In Progress --json output>');
const tasks = JSON.parse(readFileSync(tasksFile, 'utf8').replace(/^\uFEFF/, '')).tasks;
if (!Array.isArray(tasks)) throw new Error('Expected Backlog task-list JSON');
const base = git('rev-parse', 'origin/develop');
const worktrees = git('worktree', 'list', '--porcelain').split(/\r?\n\r?\n/).map(block => {
  const fields = Object.fromEntries(block.split(/\r?\n/).map(line => { const i = line.indexOf(' '); return [line.slice(0, i), line.slice(i + 1)]; }));
  const path = fields.worktree;
  const changed = git('-C', path, 'diff', '--name-only', '--no-renames', '-z', 'HEAD').split('\0').filter(Boolean);
  const untracked = git('-C', path, 'ls-files', '--others', '--exclude-standard', '-z').split('\0').filter(Boolean);
  const dirty = [...new Set([...changed, ...untracked])].map(file => {
    const full = join(path, file);
    return { path: file, sha256: existsSync(full) && lstatSync(full).isFile() ? createHash('sha256').update(readFileSync(full)).digest('hex') : null };
  });
  const committedPaths = git('-C', path, 'diff', '--name-only', '--no-renames', '-z', `${base}...HEAD`).split('\0').filter(Boolean);
  return { path, branch: fields.branch?.replace('refs/heads/', '') || null, head: fields.HEAD, status: 'unknown', dirty, committedPaths };
});
const remoteBranches = git('for-each-ref', '--format=%(refname:short) %(objectname)', 'refs/remotes/origin').split('\n').map(line => {
  const [name, head] = line.split(' '); return { name, head, executor: 'unknown' };
});
const reservations = tasks.filter(t => t.id !== 'TASK-55').map(t => ({ id: `backlog-${t.id}`, task: t.id, title: t.title, branch: null, status: 'unknown', scope: { paths: t.modifiedFiles?.length ? t.modifiedFiles : ['src', 'data', 'tests/lua'], modules: ['legacy-gameplay'] }, reason: 'In Progress is not execution ownership; exact executor and scope require acknowledgement' }));
for (const [index, w] of worktrees.entries()) {
  if (w.path.replaceAll('\\', '/').endsWith('/remote-task-claim')) continue;
  const paths = [...new Set([...w.committedPaths, ...w.dirty.map(d => d.path)])];
  if (paths.length) reservations.push({ id: `worktree-${index}`, task: 'TASK-0', branch: w.branch, status: 'unknown', scope: { paths, modules: [] }, reason: 'Legacy branch/session identity unknown; retain all files', worktree: w.path });
}
process.stdout.write(JSON.stringify({ capturedAt: new Date().toISOString(), base, externalUnknown: true, note: 'Remote machines and existing local executor sessions are unknown. No cleanup or ownership assumption.', worktrees, remoteBranches, tasks, reservations }, null, 2) + '\n');
