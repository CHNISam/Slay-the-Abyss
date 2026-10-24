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
