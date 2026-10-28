import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { selectTests, selectQuickFeedback, selectQuickPlan } from '../scripts/test-affected.mjs';

const plan = { full: false, fast: ['tests/pure.test.mjs'], integration: ['tests/heavy.test.mjs'],
  lua: ['tests/lua/slow.lua', 'tests/lua/direct.lua', 'tests/lua/small.lua', 'tests/lua/new.lua'] };
const timings = { lua: { 'tests/lua/slow.lua': 120000, 'tests/lua/direct.lua': 60000, 'tests/lua/small.lua': 10000 } };

test('quick feedback prioritizes a changed fixture and schedules whole related fixtures within an estimate', () => {
  const result = selectQuickFeedback(plan, ['tests/lua/direct.lua'], timings);
  assert.deepEqual(result, { fast: plan.fast, lua: ['tests/lua/direct.lua', 'tests/lua/small.lua'], estimatedLuaMs: 70000 });
  assert.deepEqual(plan.lua, ['tests/lua/slow.lua', 'tests/lua/direct.lua', 'tests/lua/small.lua', 'tests/lua/new.lua']);
});

test('unknown or unusable timings use a finite conservative scheduling estimate', () => {
  for (const weight of [undefined, -1, 0, NaN, Infinity, '1000']) {
    assert.deepEqual(selectQuickFeedback({ ...plan, lua: ['new'] }, [], { lua: { new: weight } }, 30000).lua, ['new']);
    assert.deepEqual(selectQuickFeedback({ ...plan, lua: ['new'] }, [], { lua: { new: weight } }, 29999).lua, []);
  }
});

test('full fallback does not become a partial success plan', () => {
  assert.deepEqual(selectQuickFeedback({ ...plan, full: true }, [], timings), { fast: [], lua: [], estimatedLuaMs: 0 });
});

test('CI mapped subset remains useful beside unknown inputs while the normal selector still requires full regression', () => {
  const sources = { 'src/lua/abyss_value.lua': 'return {}', 'tests/lua/value.lua': 'return require("abyss_value")' };
  const changed = ['docs/HANDOFF.md', 'src/lua/abyss_value.lua'];
  assert.equal(selectTests(changed, sources).full, true);
  assert.deepEqual(selectQuickPlan(changed, sources).lua, ['tests/lua/value.lua']);
  assert.equal(selectQuickPlan(['docs/HANDOFF.md'], sources).full, true);
});

test('CI-only unmapped fallback reports the full gate without launching a duplicate suite', () => {
  const env = { ...process.env }; delete env.NODE_TEST_CONTEXT; delete env.GITHUB_STEP_SUMMARY;
  const result = spawnSync(process.execPath, ['scripts/test-affected.mjs', '--ci-fast', '--files', 'docs/HANDOFF.md'],
    { encoding: 'utf8', env, windowsHide: true, timeout: 30000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Complete Quality required: Unmodelled or deleted input: docs\/HANDOFF.md/);
  assert.match(result.stdout, /Quick feedback unavailable. No tests run here; parallel complete Quality is required/);
  assert.doesNotMatch(result.stdout, /Completed|> slay-the-abyss|regression pass/);
});

test('quick workflow is independent, read-only, exact-revision and cancels only superseded PR feedback', () => {
  const workflow = readFileSync('.github/workflows/quick-feedback.yml', 'utf8').replaceAll('\r\n', '\n');
  assert.match(workflow, /workflow_dispatch:/);
  assert.doesNotMatch(workflow, /  pull_request:/);
  assert.match(workflow, /permissions:\n  contents: read/);
  assert.match(workflow, /group: quick-feedback-\$\{\{ github.ref \}\}\n  cancel-in-progress: true/);
  assert.match(workflow, /ref: \$\{\{ github.sha \}\}/);
  assert.match(workflow, /BASE_SHA: \$\{\{ inputs.base_sha \}\}/);
  assert.match(workflow, /git cat-file -e "\$\{BASE_SHA\}\^\{commit\}"/);
  assert.match(workflow, /timeout-minutes: 2\n        env:\n          BASE_SHA:/);
  assert.match(workflow, /GIT_TERMINAL_PROMPT: '0'/);
  assert.match(workflow, /if ! git cat-file -e "\$\{BASE_SHA\}\^\{commit\}" 2>\/dev\/null; then\n            git -c credential.helper= -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=30 fetch --depth=1 --no-auto-maintenance --no-tags origin "\$BASE_SHA"\n          fi\n          git cat-file -e/);
  assert.match(workflow, /node scripts\/test-affected.mjs --ci-fast --base "\$BASE_SHA"/);
  assert.doesNotMatch(workflow, /pull_request_target|self-hosted|needs:|continue-on-error|npm run check/);
});
