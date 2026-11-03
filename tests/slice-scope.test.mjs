import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { auditSlice, checkPolicy, parseChangedPaths, run } from '../scripts/check-slice-scope.mjs';

test('pilot lanes have unique owners and safe in-tree paths', () => {
  assert.deepEqual(checkPolicy(), []);
  assert.match(checkPolicy({a:['a/b.lua'],b:['a/b.lua']}).join(' '), /owned by both/);
  assert.match(checkPolicy({a:['../oops']}).join(' '), /invalid path/);
});

test('a slice can modify only its own domain; shared Backlog and CI are excluded', () => {
  assert.equal(auditSlice('slice/actor-damage/extract', ['src/lua/abyss_actor.lua','tests/actor-damage-pipeline.test.mjs']).decision,'PASS');
  const out = auditSlice('slice/actor-damage/extract', [
    'src/lua/abyss_actor.lua','src/lua/abyss_game_ui.lua','backlog/tasks/task-74.md','.github/workflows/quality.yml',
  ]);
  assert.equal(out.decision,'HOLD');
  assert.equal(out.errors.length,3);
  assert.match(out.errors.join('\n'), /backlog\/tasks/);
});

test('legacy branches remain unaffected; unknown/invalid lanes fail closed', () => {
  assert.equal(auditSlice('feat/hot-fix', ['backlog/tasks/task-74.md']).decision,'SKIP');
  assert.equal(auditSlice('slice/other/foo', ['src/lua/abyss_actor.lua']).decision,'HOLD');
  assert.equal(auditSlice('slice/actor-damage', ['src/lua/abyss_actor.lua']).decision,'HOLD');
  assert.equal(auditSlice('slice/actor-damage/foo', []).decision,'HOLD');
});

test('rename/copy diff checks both touched paths', () => {
  assert.deepEqual(parseChangedPaths('M\0src/lua/abyss_actor.lua\0R100\0src/lua/abyss_actor.lua\0src/lua/abyss_game_ui.lua\0'), [
    'src/lua/abyss_actor.lua','src/lua/abyss_actor.lua','src/lua/abyss_game_ui.lua',
  ]);
  assert.equal(auditSlice('slice/actor-damage/foo',parseChangedPaths('R100\0src/lua/abyss_actor.lua\0src/lua/abyss_game_ui.lua\0')).decision,'HOLD');
  assert.throws(()=>parseChangedPaths('R100\0src/lua/abyss_actor.lua\0'), /incomplete/);
  assert.throws(()=>parseChangedPaths('X999\0oops\0'), /invalid diff status/);
});

test('the command uses an exact base commit and runs without any API or model calls', () => {
  const base = 'a'.repeat(40);
  const calls=[];
  const result=run({branch:'slice/ci-cost/profile',base,git:(exe,args,opts)=>{
    calls.push({exe,args,opts});
    return 'M\0scripts/ci-run-costs.mjs\0';
  }});
  assert.equal(result.decision,'PASS');
  assert.equal(calls.length,1);
  assert.deepEqual(calls[0].args.slice(-2),[base,'HEAD']);
  assert.throws(()=>run({branch:'slice/ci-cost/profile',base:'main'}),/40-character/);
  assert.equal(run({branch:'feat/ordinary'}).decision,'SKIP');
});

test('existing CI impact job calls the scope checker without a new job', () => {
  const workflow = readFileSync('.github/workflows/quality.yml','utf8');
  assert.match(workflow, /name: Enforce opt-in slice write scopes\n[\s\S]*?run: node scripts\/check-slice-scope\.mjs/);
  assert.match(workflow, /SLICE_BASE_SHA: \$\{\{ github\.event\.pull_request\.base\.sha \}\}/);
});
