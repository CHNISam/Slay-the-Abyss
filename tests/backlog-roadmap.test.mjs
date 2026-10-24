import test from 'node:test';
import assert from 'node:assert/strict';
import { auditRoadmap, readTaskHeader } from '../scripts/verify-backlog-roadmap.mjs';

const milestone = { 'm-2': 'M1', 'm-5': 'M4' };
const task = (id, extra = {}) => ({ id, status: 'To Do', milestone: 'm-5', assignees: ['@Codex'], ...extra });
test('CLI-written inline and block lists retain owner, milestone and parent identity', () => {
  for (const assignee of ['assignee: ["@Codex"]', "assignee:\r\n  - '@Codex'"]) {
    const parsed = readTaskHeader(`---\r\nid: TASK-10.5.1\r\nstatus: In Progress\r\n${assignee}\r\nmilestone: m-2\r\nparent_task_id: TASK-10.5\r\nlabels: []\r\n---\r\n`);
    assert.deepEqual(parsed.assignees, ['@Codex']);
    assert.equal(parsed.milestone, 'm-2');
    assert.equal(parsed.parentTaskId, 'TASK-10.5');
  }
});
test('a newly registered launch task cannot disappear from the roadmap', () => {
  const errors = auditRoadmap([task('TASK-4.2')], '### M4\n- TASK-4：总验收', milestone);
  assert.ok(errors.some(e => e.includes('TASK-4.2') && e.includes('排期')));
});
test('an unowned or malformed owner fails even when the task is scheduled', () => {
  for (const assignees of [[], ['--plan']]) {
    assert.ok(auditRoadmap([task('TASK-4.2', { assignees })], '### M4\n- TASK-4.2：背景', milestone).some(e => e.includes('负责人')));
  }
});
test('wrong milestone section and unknown milestone fail', () => {
  assert.ok(auditRoadmap([task('TASK-4.2')], '### M1\n- TASK-4.2：背景', milestone).length);
  assert.ok(auditRoadmap([task('TASK-4.2', { milestone: 'missing' })], '', milestone).length);
});
test('active children of a completed launch slice still require their own milestone', () => {
  const tasks = [task('TASK-10.5', { status: 'Done', milestone: 'm-2' }),
    task('TASK-10.5.1', { milestone: null, parentTaskId: 'TASK-10.5' })];
  assert.ok(auditRoadmap(tasks, '', milestone).some(e => e.includes('TASK-10.5.1') && e.includes('里程碑')));
});
test('completed slices and optional work do not become new launch blockers', () => {
  assert.deepEqual(auditRoadmap([task('TASK-25.1', { status: 'Done', assignees: [] }),
    task('TASK-45', { milestone: null, assignees: [] })], '', milestone), []);
});
test('valid launch tasks pass with exact IDs in their milestone section', () => {
  assert.deepEqual(auditRoadmap([task('TASK-4.2')], '### M4\n- TASK-4.2：背景', milestone), []);
});
test('scheduled launch roots remain audited after both milestone and owner are lost', () => {
  const errors = auditRoadmap([task('TASK-47', { milestone: null, assignees: [] })],
    '### M3\n- TASK-47：首发清单', milestone);
  assert.ok(errors.some(error => error.includes('TASK-47') && error.includes('里程碑')));
  assert.ok(errors.some(error => error.includes('TASK-47') && error.includes('负责人')));
});
test('milestone headings can include a human-readable explanation', () => {
  assert.deepEqual(auditRoadmap([task('TASK-4.2')], '### M4 达到正式作品品质\n- TASK-4.2：背景', milestone), []);
});

import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { verifyBacklogRoadmap } from '../scripts/verify-backlog-roadmap.mjs';

test('roadmap phase headings support an adjacent ASCII pipe without confusing phase prefixes', () => {
  assert.deepEqual(auditRoadmap([task('TASK-4.2')], '### M4|达到正式作品品质\n- TASK-4.2：背景', milestone), []);
  for (const heading of ['M40', 'M4x', 'M4other']) {
    assert.ok(auditRoadmap([task('TASK-4.2')], `### ${heading}\n- TASK-4.2：背景`, milestone)
      .some(error => error.includes('排期')));
  }
});

test('CLI milestone titles use phase identity rather than one display separator', t => {
  const root = mkdtempSync(join(tmpdir(), 'backlog-roadmap-title-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const directory of ['backlog/tasks', 'backlog/completed', 'backlog/milestones', 'docs']) {
    mkdirSync(join(root, directory), { recursive: true });
  }
  writeFileSync(join(root, 'backlog/tasks/task-4.2.md'), '---\nid: TASK-4.2\nstatus: To Do\nmilestone: m-5\nassignee: ["@Codex"]\n---\n');
  writeFileSync(join(root, 'docs/MILESTONES.md'), '### M4\n- TASK-4.2：背景\n');
  for (const newline of ['\n', '\r\n']) for (const quote of ['', '"', "'"]) {
    for (const title of ['M4｜正式作品品质', 'M4|正式作品品质', 'M4 正式作品品质', 'M4：正式作品品质', 'M4: 正式作品品质', 'M4']) {
      writeFileSync(join(root, 'backlog/milestones/m-5.md'), ['---', 'id: m-5', `title: ${quote}${title}${quote}`, '---', ''].join(newline));
      assert.deepEqual(verifyBacklogRoadmap(root), [], `${quote}${title}${quote}, newline=${JSON.stringify(newline)}`);
    }
    for (const title of ['M40', 'M4x', 'M4other']) {
      writeFileSync(join(root, 'backlog/milestones/m-5.md'), ['---', 'id: m-5', `title: ${quote}${title}${quote}`, '---', ''].join(newline));
      assert.ok(verifyBacklogRoadmap(root).some(error => error.includes('里程碑')), title);
    }
  }
});

function backlogFixture(t, entries, roadmap = '') {
  const root = mkdtempSync(join(tmpdir(), 'backlog-id-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const directory of ['backlog/tasks', 'backlog/completed', 'backlog/milestones', 'docs']) {
    mkdirSync(join(root, directory), { recursive: true });
  }
  writeFileSync(join(root, 'backlog/milestones/m-5.md'), '---\nid: m-5\ntitle: M4｜正式作品品质\n---\n');
  writeFileSync(join(root, 'docs/MILESTONES.md'), roadmap);
  for (const [path, id, status = 'Done', metadata = ''] of entries) {
    writeFileSync(join(root, path), `---\nid: ${id}\ntitle: 中文任务标题\nstatus: ${status}\n${metadata}---\n`);
  }
  return root;
}

const diagnosticPath = 'backlog/tasks/task-52.1 - 修复旧路线诊断的领奖步骤.md';
const hudPath = 'backlog/tasks/task-52.1 - 领取药水后立即刷新顶部药水栏.md';
const completedPath = 'backlog/completed/task-52.1 - 已完成切片.md';
const launchMetadata = 'milestone: m-5\nassignee: ["@Codex"]\n';
for (const [name, entries] of [
  ['two active tasks', [[diagnosticPath, 'TASK-52.1', 'In Progress', launchMetadata], [hudPath, 'TASK-52.1', 'To Do', launchMetadata]]],
  ['the two Done TASK-52.1 slices in the active directory', [[diagnosticPath, 'TASK-52.1'], [hudPath, 'TASK-52.1']]],
  ['active and completed tasks', [[diagnosticPath, 'TASK-52.1', 'In Progress', launchMetadata], [completedPath, 'TASK-52.1']]],
  ['two completed tasks', [[completedPath, 'TASK-52.1'], ['backlog/completed/task-52.1 - 另一历史切片.md', 'TASK-52.1']]],
  ['all three colliding files', [[diagnosticPath, 'TASK-52.1'], [hudPath, 'TASK-52.1'], [completedPath, 'TASK-52.1']]],
]) {
  test(`duplicate identity reports the ID and every file for ${name}`, t => {
    const root = backlogFixture(t, entries, '### M4\n- TASK-52.1：测试排期\n');
    const errors = verifyBacklogRoadmap(root);
    assert.ok(errors.some(error => /重复/.test(error) && error.includes('TASK-52.1')), errors.join('\n'));
    for (const [path] of entries) assert.ok(errors.some(error => error.includes(path)), `Missing file: ${path}`);
  });
}

test('duplicate identity follows native case, numeric padding and unprefixed ID semantics', t => {
  for (const [first, second, canonical] of [
    ['TASK-52.1', 'task-52.1', 'TASK-52.1'],
    ['TASK-52.1', 'TASK-052.01', 'TASK-52.1'],
    ['TASK-52.1', '052.001', 'TASK-52.1'],
    ['Feature-ABC', 'FEATURE-abc', 'FEATURE-ABC'],
    ['BUG-002.000', 'bug-2.0', 'BUG-2.0'],
  ]) {
    const root = backlogFixture(t, [[diagnosticPath, first], [completedPath, second]]);
    const errors = verifyBacklogRoadmap(root);
    assert.ok(errors.some(error => /重复/.test(error) && error.includes(canonical)), `${first} / ${second}: ${errors}`);
    for (const path of [diagnosticPath, completedPath]) assert.ok(errors.some(error => error.includes(path)), path);
  }
});

test('distinct prefixes, exact numeric segments and nonnumeric IDs remain valid', t => {
  const ids = ['TASK-52.1', 'TASK-52.2', 'BUG-52.1', 'Feature-ABC', 'Feature-DEF',
    'TASK-9007199254740992', 'TASK-9007199254740993', 'TASK-52.10'];
  const entries = ids.map((id, i) => [`backlog/tasks/task-${i} - 中文标题.md`, id]);
  entries.push(['backlog/completed/task-53 - 历史记录.md', 'TASK-53']);
  assert.deepEqual(verifyBacklogRoadmap(backlogFixture(t, entries)), []);
});

test('completed records participate only in identity checks, not active launch scheduling', t => {
  const root = backlogFixture(t, [
    ['backlog/completed/task-53 - 旧记录.md', 'TASK-53', 'Closed', 'milestone: archived-milestone\nassignee: []\n'],
    ['backlog/tasks/task-54 - 当前任务.md', 'TASK-54', 'In Progress', launchMetadata],
  ], '### M4\n- TASK-54：当前任务\n');
  assert.deepEqual(verifyBacklogRoadmap(root), []);
});

test('an active child still needs metadata when its launch parent is in completed', t => {
  const root = backlogFixture(t, [
    ['backlog/completed/task-53 - 已完成首发任务.md', 'TASK-53', 'Done', 'milestone: archived-milestone\n'],
    ['backlog/tasks/task-53.1 - 活动子任务.md', 'TASK-53.1', 'In Progress', 'parent_task_id: TASK-53\n'],
  ]);
  const errors = verifyBacklogRoadmap(root);
  assert.ok(errors.some(error => error.startsWith('TASK-53.1:') && error.includes('里程碑')), errors.join('\n'));
  assert.ok(errors.some(error => error.startsWith('TASK-53.1:') && error.includes('负责人')), errors.join('\n'));
  assert.equal(errors.length, 2, 'Only the active child is audited; the historical parent is not rescheduled');
});

test('the existing command exits nonzero and names both Done files on a duplicate ID', t => {
  const root = backlogFixture(t, [[diagnosticPath, 'TASK-52.1'], [hudPath, 'TASK-52.1']]);
  const script = fileURLToPath(new URL('../scripts/verify-backlog-roadmap.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [script], { cwd: root, encoding: 'utf8' });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /TASK-52\.1/);
  for (const path of [diagnosticPath, hudPath]) assert.ok(result.stderr.includes(path), path);
});
