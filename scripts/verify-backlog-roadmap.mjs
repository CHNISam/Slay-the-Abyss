import { readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Read-only: intentionally restricted to the scalar/list fields written by Backlog CLI.
// All changes to these files must still go through that CLI.
export function readTaskHeader(source) {
  const header = source.replace(/^\uFEFF/, '').split(/^---\s*$/m)[1] ?? '';
  const scalar = key => header.match(new RegExp(`^${key}:\\s*([^\\r\\n]+)`, 'm'))?.[1].trim().replace(/^['"]|['"]$/g, '') ?? null;
  const list = key => {
    const inline = header.match(new RegExp(`^${key}:[ \\t]*\\[([^\\r\\n]*)\\]`, 'm'));
    if (inline) return inline[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
    const block = header.match(new RegExp(`^${key}:[ \\t]*\\r?\\n((?:[ \\t]+-[^\\r\\n]*\\r?\\n?)+)`, 'm'));
    return [...(block?.[1] ?? '').matchAll(/^[ \t]+-[ \t]+(.+)$/gm)].map(m => m[1].trim().replace(/^['"]|['"]$/g, ''));
  };
  return { id: scalar('id'), status: scalar('status'), milestone: scalar('milestone'),
    parentTaskId: scalar('parent_task_id'), assignees: list('assignee'), labels: list('labels') };
}

export function auditRoadmap(tasks, roadmap, milestones) {
  const errors = [], byId = new Map(tasks.map(task => [task.id, task]));
  const sections = new Map();
  let section;
  for (const line of roadmap.split(/\r?\n/)) {
    const heading = line.match(/^###\s+(M[1-6])(?:\s|[｜:：]|$)/);
    if (heading) section = heading[1];
    else if (/^#{1,3} /.test(line)) section = null;
    if (section) for (const match of line.matchAll(/^- (TASK-\d+(?:\.\d+)*)(?=[：:\s])/g)) sections.set(match[1], section);
  }
  function isLaunch(task, seen = new Set()) {
    if (!task || seen.has(task.id)) return false;
    seen.add(task.id);
    return Boolean(sections.has(task.id) || task.milestone || task.labels?.includes('launch') || isLaunch(byId.get(task.parentTaskId), seen));
  }
  for (const task of tasks) {
    if (task.status === 'Done' || !isLaunch(task)) continue;
    if (!task.milestone || !milestones[task.milestone]) errors.push(`${task.id}: 缺少有效首发里程碑`);
    else if (sections.get(task.id) !== milestones[task.milestone]) errors.push(`${task.id}: 未列入 ${milestones[task.milestone]} 排期`);
    if (!task.assignees?.length || task.assignees.some(owner => !owner.trim() || owner.startsWith('--'))) errors.push(`${task.id}: 缺少有效负责人`);
  }
  return errors;
}

export function verifyBacklogRoadmap(root = '.') {
  const files = directory => readdirSync(join(root, directory)).filter(name => name.endsWith('.md')).map(name => readFileSync(join(root, directory, name), 'utf8'));
  const tasks = [...files('backlog/tasks'), ...files('backlog/completed')].map(readTaskHeader);
  const milestones = Object.fromEntries(files('backlog/milestones').map(source => {
    const id = source.match(/^id:\s*(m-\d+)/m)?.[1];
    const stage = source.match(/^title:\s*["']?(M[1-6])[｜|]/m)?.[1];
    return [id, stage];
  }).filter(([id, stage]) => id && stage));
  return auditRoadmap(tasks, readFileSync(join(root, 'docs/MILESTONES.md'), 'utf8'), milestones);
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const errors = verifyBacklogRoadmap();
  if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
  else console.log('未完成首发任务的里程碑、排期和负责人检查通过；不认证平台或实机。');
}
