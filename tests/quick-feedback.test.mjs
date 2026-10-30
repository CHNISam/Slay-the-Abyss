import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { selectTests, selectQuickFeedback, selectQuickPlan, executeQuickFeedback } from '../scripts/test-affected.mjs';
import { historicalMonsterUiFixtures } from './helpers/historical-monster-ui-runner.mjs';
import { historicalCardInputFixtures } from './helpers/historical-card-input.mjs';
import { historicalPresentationFixtures } from './helpers/historical-presentation-runner.mjs';

const plan = { full: false, fast: ['tests/pure.test.mjs'], integration: ['tests/heavy.test.mjs'],
  lua: ['tests/lua/slow.lua', 'tests/lua/direct.lua', 'tests/lua/small.lua', 'tests/lua/new.lua'] };
const timings = { lua: { 'tests/lua/slow.lua': 120000, 'tests/lua/direct.lua': 60000, 'tests/lua/small.lua': 10000 } };

test('direct changed Lua runs before JS and remaining Lua without duplicate execution', () => {
  const calls = [];
  executeQuickFeedback({fast:['pure'],lua:['related','direct','other-direct']}, ['direct','other-direct'], {
    js: files => calls.push(['js',files]), lua: file => calls.push(['lua',file]),
  });
  assert.deepEqual(calls,[['lua','direct'],['lua','other-direct'],['js',['pure']],['lua','related']]);
});

test('an advisory failure propagates immediately and prevents later tests', () => {
  for(const failure of ['direct','js','related']) {
    const calls = [], error = new Error(failure);
    const step = name => { calls.push(name); if(name===failure) throw error; };
    assert.throws(()=>executeQuickFeedback({fast:['pure'],lua:['related','direct','later']},['direct'],{
      js:()=>step('js'),lua:step,
    }),value=>value===error);
    assert.deepEqual(calls, ['direct','js','related'].slice(0,['direct','js','related'].indexOf(failure)+1));
  }
});

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

test('mixed advisory changes build the graph once and ignore every unmapped input', () => {
  let reads=0;
  const sources={
    get 'scripts/value.mjs'(){reads++;return 'export const value=1';},
    'scripts/unmapped.mjs':'return true',
    'src/lua/unmapped.lua':'return true',
    'tests/first.test.mjs':'import "../scripts/value.mjs"',
    'tests/second.test.mjs':'return true',
    'tests/dynamic.test.mjs':'runLua(path)',
  };
  const changed=['docs/HANDOFF.md','scripts/value.mjs','tests/second.test.mjs',
    'scripts/unmapped.mjs','src/lua/unmapped.lua','scripts/test-lua.mjs'];
  const full=selectTests(changed,sources);
  assert.equal(full.full,true);
  const quick=selectQuickPlan(changed,sources,full);
  assert.equal(reads,1,'one graph analysis for the entire mixed changeset');
  assert.deepEqual(quick.fast,['tests/first.test.mjs','tests/second.test.mjs']);
  assert.deepEqual(quick.integration,[],'an unmapped Lua input cannot expand advisory coverage');
  assert.equal(quick.full,false);
  assert.equal(full.full,true,'complete-gate fallback is unchanged');
});

test('a multi-file advisory with no statically mapped inputs remains unavailable', () => {
  const sources={'scripts/unmapped.mjs':'return true','src/lua/unmapped.lua':'return true',
    'tests/dynamic.test.mjs':'runLua(path)'};
  const plan=selectQuickPlan(['docs/HANDOFF.md','scripts/unmapped.mjs','src/lua/unmapped.lua'],sources);
  assert.equal(plan.full,true);
  assert.deepEqual([plan.fast,plan.integration,plan.lua],[[],[],[]]);
});

test('a hundred-file advisory still reads each graph source once', context => {
  let reads=0;
  const names=Array.from({length:100},(_,index)=>`tests/changed-${index}.test.mjs`);
  const sources=Object.fromEntries(names.map(path=>[path,'return true']));
  Object.defineProperty(sources,'scripts/value.mjs',{enumerable:true,get(){reads++;return 'export const value=1';}});
  const started=performance.now();
  const plan=selectQuickPlan(['docs/unknown.md',...names],sources);
  context.diagnostic(`100-file advisory planning: ${(performance.now()-started).toFixed(2)} ms`);
  assert.equal(reads,1);
  assert.equal(plan.full,false);assert.deepEqual(plan.fast,names);
});

for (const [helper, fixtures] of [
  ['historical-presentation-runner', historicalPresentationFixtures],
  ['historical-monster-ui-runner', historicalMonsterUiFixtures],
  ['historical-card-input', historicalCardInputFixtures],
]) test(`${helper} changes select every conditional fixture and exclude unrelated wrappers`, () => {
  const path = `tests/helpers/${helper}.mjs`;
  const sources = {
    [path]: 'export const setup=1',
    ...Object.fromEntries(fixtures.map(fixture => [fixture, 'return true'])),
    'scripts/test-lua.mjs': `import {setup} from '../${path}'; export function runLua(path){}`,
    'tests/lua/unrelated.lua': 'return true',
    'tests/unrelated.test.mjs': 'import {runLua} from "../scripts/test-lua.mjs"; runLua("tests/lua/unrelated.lua")',
    'tests/conditional.test.mjs': `import {runLua} from '../scripts/test-lua.mjs'; runLua('${fixtures[0]}')`,
  };
  const plan = selectTests([path], sources);
  assert.equal(plan.full, false);
  assert.deepEqual(plan.lua, fixtures);
  assert.deepEqual(plan.integration, ['tests/conditional.test.mjs']);
  if(helper==='historical-presentation-runner') {
    const archive='tests/fixtures/pr323-historical-fixtures.json.gz';
    assert.equal(fixtures.length,6,'trace, wording and all four Sapphire entries');
    assert.equal(selectTests([archive,path],sources).full,true,'archive changes still require Full');
    assert.deepEqual(selectQuickPlan([archive,path],sources).lua,fixtures,'mixed advisory retains every mapped runtime entry');
    assert.equal(selectQuickPlan([archive],sources).full,true,'archive-only advisory cannot claim a partial test pass');
  }
});

for (const flag of ['--fast', '--ci-fast']) test(`${flag} unmapped fallback reports the full gate without launching a duplicate suite`, () => {
  const env = { ...process.env }; delete env.NODE_TEST_CONTEXT; delete env.GITHUB_STEP_SUMMARY;
  const result = spawnSync(process.execPath, ['scripts/test-affected.mjs', flag, '--files', 'docs/HANDOFF.md'],
    { encoding: 'utf8', env, windowsHide: true, timeout: 30000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Complete Quality required: Unmodelled or deleted input: docs\/HANDOFF.md/);
  assert.match(result.stdout, /Quick feedback unavailable. No tests run here; parallel complete Quality is required/);
  assert.match(result.stdout, /not a regression pass/);
  assert.match(result.stdout, /Feedback timing: plan \d+ ms\./);
  assert.doesNotMatch(result.stdout, /Completed|> slay-the-abyss/);
});

test('local and CI advisory plans select the same real Lua feedback', () => {
  const plans = ['--fast', '--ci-fast'].map(flag => {
    const result = spawnSync(process.execPath, ['scripts/test-affected.mjs', flag, '--plan', '--files', 'tests/lua/combat.lua'],
      { encoding: 'utf8', windowsHide: true, timeout: 30000 });
    assert.equal(result.status, 0, result.stderr);
    const plan = JSON.parse(result.stdout);
    assert.ok(Number.isSafeInteger(plan.planDurationMs) && plan.planDurationMs >= 0);
    return plan;
  });
  assert.deepEqual(plans[0].feedback, plans[1].feedback);
  assert.ok(plans[0].feedback.lua.includes('tests/lua/combat.lua'));
});

test('quick workflow is independent, read-only, exact-revision and cancels only superseded PR feedback', () => {
  const workflow = readFileSync('.github/workflows/quick-feedback.yml', 'utf8').replaceAll('\r\n', '\n');
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /  pull_request:\n    branches: \[develop\]/);
  assert.match(workflow, /permissions:\n  contents: read/);
  assert.match(workflow, /group: quick-feedback-\$\{\{ github.ref \}\}\n  cancel-in-progress: true/);
  assert.match(workflow, /ref: \$\{\{ github.sha \}\}/);
  assert.match(workflow, /BASE_SHA: \$\{\{ github.event.pull_request.base.sha \|\| inputs.base_sha \}\}/);
  assert.match(workflow, /git cat-file -e "\$\{BASE_SHA\}\^\{commit\}"/);
  assert.match(workflow, /timeout-minutes: 2\n        env:\n          BASE_SHA:/);
  assert.match(workflow, /GIT_TERMINAL_PROMPT: '0'/);
  assert.match(workflow, /if ! git cat-file -e "\$\{BASE_SHA\}\^\{commit\}" 2>\/dev\/null; then\n            git -c credential.helper= -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=30 fetch --depth=1 --no-auto-maintenance --no-tags origin "\$BASE_SHA"\n          fi\n          git cat-file -e/);
  assert.match(workflow, /node scripts\/test-affected.mjs --ci-fast --base "\$BASE_SHA"/);
  assert.doesNotMatch(workflow, /pull_request_target|self-hosted|needs:|continue-on-error|npm run check/);
});
