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
  return { id: scalar('id'), status: scalar('status'), priority: scalar('priority'), milestone: scalar('milestone'),
    parentTaskId: scalar('parent_task_id'), assignees: list('assignee'), labels: list('labels') };
}

// Priority describes the current queue, not whether a launch requirement matters.
// Historical completed/ records are deliberately not reclassified.
export function auditPriorities(tasks) {
  const errors = [], high = [];
  for (const task of tasks) {
    if (!['high', 'medium', 'low'].includes(task.priority)) errors.push(`${task.id}: 缺少有效优先级（high/medium/low）`);
    if (task.priority !== 'high') continue;
    if (task.status === 'Done') errors.push(`${task.id}: 已完成任务不应占用当前 High 队列`);
    else high.push(task.id);
  }
  if (high.length > 5) errors.push(`未完成 High 任务 ${high.length} 项，超过5项上限：${high.join('、')}；请按依赖重新排序`);
  return errors;
}

export function auditQueueOwners(tasks) {
  return tasks.filter(task => task.status !== 'Done' && (!task.assignees?.length
    || task.assignees.some(owner => !owner.trim() || owner.startsWith('--'))))
    .map(task => `${task.id}: 缺少有效负责人`);
}

export function auditMilestoneScope(titles) {
  const contracts = [
    // 2026-10-29 confirmed Traveler-only/two-act scope supersedes the two-role release.
    { stage: 'M3', required: ['岩系旅行者', '第一幕', '第二幕', '核心闭环'] },
    { stage: 'M4', required: ['前两幕', '首局', 'UI', '输入', '音画', '性能'] },
  ];
  return contracts.flatMap(({ stage, required }) => {
    const matches = titles.filter(title => new RegExp(`^${stage}(?:[\\s｜|:：]|$)`).test(title));
    const retiredScope = /第三幕|第四幕|四幕|全章节|两职业|双职业|四职业|八职业|全职业|雷电/;
    return matches.length === 1 && required.every(part => matches[0].includes(part)) && !retiredScope.test(matches[0]) ? []
      : [`${stage}: 里程碑范围必须明确包含${required.join('、')}，不得恢复两职业或扩大为四/八/全职业、第三/四幕，也不得退回仅第一幕或缺少该关口`];
  });
}

export function auditCompetitionRoster(scope) {
  // Only the current decision is authoritative; historical rosters elsewhere stay intact.
  // The current public roster must not silently restore Raiden or an arbitrary role.
  const current = scope.split(/^##[ \t]+/m).slice(1)
    .filter(section => /^2026-10-29 比赛单角色收敛决策[ \t]*\r?\n/.test(section));
  const decisions = current.length === 1 ? current[0].match(/最终选择[^。\r\n]*。/g) ?? [] : [];
  const frozenDecision = '最终选择仅岩系旅行者（Ironclad）完整玩通第一幕与第二幕并正常结算。';
  return decisions.length === 1 && decisions[0] === frozenDecision ? []
    : ['M3: 比赛职业合同必须仅为岩系旅行者（Ironclad）完整通关第一幕与第二幕；不得替换角色或恢复两职业公开范围'];
}

export function verifyMilestoneScope(root = '.') {
  const directory = join(root, 'backlog/milestones');
  const titles = readdirSync(directory).filter(name => name.endsWith('.md')).map(name => {
    const source = readFileSync(join(directory, name), 'utf8');
    return source.match(/^title:[ \t]*([^\r\n]*)/m)?.[1].trim().replace(/^['"]|['"]$/g, '') ?? '';
  });
  return [...auditMilestoneScope(titles), ...auditCompetitionRoster(readFileSync(join(root, 'docs/SCOPE.md'), 'utf8'))];
}

// Match Backlog's identity comparison, not a task-ID format requirement.
function taskIdentity(id) {
  const value = id.trim(), prefix = value.match(/^([a-z]+)-/i)?.[1] ?? 'TASK';
  const suffix = value.replace(new RegExp(`^${prefix}-`, 'i'), '');
  const normalized = /^\d+(?:\.\d+)*$/.test(suffix)
    ? suffix.split('.').map(part => part.replace(/^0+/, '') || '0').join('.') : suffix;
  return `${prefix}-${normalized}`.toUpperCase();
}

export function auditRoadmap(tasks, roadmap, milestones, completed = []) {
  const errors = [], identities = new Map();
  for (const task of [...tasks, ...completed]) {
    if (!task.id) continue;
    const id = taskIdentity(task.id), matches = identities.get(id) ?? [];
    matches.push(task.filePath ?? task.id);
    identities.set(id, matches);
  }
  for (const [id, paths] of identities) {
    if (paths.length > 1) errors.push(`${id}: 重复任务编号：${paths.join('；')}`);
  }
  // Ambiguous identities cannot safely resolve parents or roadmap entries.
  if (errors.length) return errors;
  // Completed parents retain launch ancestry, but only active-directory tasks are audited below.
  const byId = new Map([...tasks, ...completed].map(task => [task.id, task]));
  const sections = new Map();
  let section;
  for (const line of roadmap.split(/\r?\n/)) {
    const heading = line.match(/^###\s+(M[1-6])(?:\s|[｜|:：]|$)/);
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
  const files = directory => readdirSync(join(root, directory)).filter(name => name.endsWith('.md')).sort().map(name => ({
    filePath: `${directory}/${name}`, source: readFileSync(join(root, directory, name), 'utf8') }));
  const readTasks = directory => files(directory).map(({ filePath, source }) => ({ ...readTaskHeader(source), filePath }));
  const tasks = readTasks('backlog/tasks'), completed = readTasks('backlog/completed');
  const milestones = Object.fromEntries(files('backlog/milestones').map(({ source }) => {
    const id = source.match(/^id:\s*(m-\d+)/m)?.[1];
    const title = source.match(/^title:[ \t]*([^\r\n]*)/m)?.[1].trim().replace(/^['"]|['"]$/g, '') ?? '';
    const stage = title.match(/^(M[1-6])(?:\s|[｜|:：]|$)/)?.[1];
    return [id, stage];
  }).filter(([id, stage]) => id && stage));
  return [...new Set([...auditRoadmap(tasks, readFileSync(join(root, 'docs/MILESTONES.md'), 'utf8'), milestones, completed),
    ...auditPriorities(tasks), ...auditQueueOwners(tasks)])];
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const errors = [...verifyBacklogRoadmap(), ...verifyMilestoneScope()];
  if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
  else console.log('任务编号、首发排期、负责人及仅岩系旅行者前两幕规划范围检查通过；当前任务均有优先级、未完成High不超过5项；不认证运行时准入、平台或实机。');
}
