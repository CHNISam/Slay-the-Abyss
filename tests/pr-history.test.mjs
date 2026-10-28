import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkHistory, auditHistory } from '../scripts/check-pr-history.mjs';

const sha = n => n.toString(16).padStart(40, '0');
const commit = n => ({ sha: sha(n), parents: [{ sha: sha(n - 1) }] });
const event = { pull_request: { base: { ref: 'develop', sha: sha(0), repo: { full_name: 'owner/repo' } }, head: { sha: sha(101) } } };

test('linear feature commits pass; cross-feature merges and incomplete history fail', () => {
  checkHistory([commit(1), commit(2)], 2, sha(2));
  for (const commits of [[], [commit(1)], [commit(2), commit(2)],
    [commit(1), { ...commit(2), parents: [{ sha: sha(1) }, { sha: sha(3) }] }],
    [commit(1), { sha: sha(2) }]]) assert.throws(() => checkHistory(commits, 2, sha(2)));
});

test('the immutable comparison is paginated and a merge on the last page is rejected', async () => {
  const calls = [];
  let last = commit(101);
  const request = async path => {
    calls.push(path);
    return { total_commits: 101, base_commit: { sha: sha(0) },
      commits: path.endsWith('page=1') ? Array.from({ length: 100 }, (_, i) => commit(i + 1)) : [last] };
  };
  assert.equal((await auditHistory(event, 'owner/repo', request)).status, 'linear');
  assert.deepEqual(calls.map(path => path.slice(-6)), ['page=1', 'page=2']);
  assert.ok(calls.every(path => path.includes(`${sha(0)}...${sha(101)}`)));
  last = { ...last, parents: [{ sha: sha(100) }, { sha: sha(200) }] };
  await assert.rejects(auditHistory(event, 'owner/repo', request), /Keep feature branches linear/);
  await assert.rejects(auditHistory(event, 'owner/repo', async () => { throw new Error('offline'); }), /offline/);
  await assert.rejects(auditHistory(event, 'wrong/repo', request), /identity/);
  await assert.rejects(auditHistory(event, 'owner/repo', async () => ({ total_commits: 1, base_commit: { sha: sha(3) }, commits: [commit(101)] })), /base mismatch/);
  assert.equal((await auditHistory({ pull_request: { base: { ref: 'master' } } }, '', request)).status, 'release-policy');
});

test('the existing required Quality checks history once before installing dependencies', () => {
  const workflow = readFileSync('.github/workflows/quality.yml', 'utf8');
  assert.equal(workflow.split('run: node scripts/check-pr-history.mjs').length - 1, 1);
  assert.match(workflow, /name: Check feature branch history\r?\n        if: github.event_name == 'pull_request' && matrix.shard == 1/);
  assert.ok(workflow.indexOf('run: node scripts/check-pr-history.mjs') < workflow.indexOf('- run: npm ci'));
});
