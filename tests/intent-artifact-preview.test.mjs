import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('generated GameUI intent previews respect ordered Artifact gates without mutating combat', () => {
  buildLuaData();
  buildUI();
  // Independent concerns retain the runner's unchanged per-script deadline.
  const gateCases=[];
  for (const [script, marker, cases] of [
    ['tests/lua/intent_artifact_preview.lua', /^LUA_INTENT_ARTIFACT_PREVIEW 4 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_debuff_gates.lua', /^LUA_INTENT_ARTIFACT_DEBUFF_GATES 1 passed; 0 failed$/m,[1]],
    ['tests/lua/intent_artifact_debuff_gates_slice_2.lua', /^LUA_INTENT_ARTIFACT_DEBUFF_GATES 2 passed; 0 failed$/m,[2,3]],
    ['tests/lua/intent_artifact_ordered_interactions.lua', /^LUA_INTENT_ARTIFACT_ORDERED_INTERACTIONS 5 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_playback.lua', /^LUA_INTENT_ARTIFACT_PLAYBACK 1 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_charges.lua', /^LUA_INTENT_ARTIFACT_CHARGES 1 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_cancellation.lua', /^LUA_INTENT_ARTIFACT_CANCELLATION 1 passed; 0 failed$/m],
  ]) {
    const startedAt = Date.now();
    const result = runLua(script);
    console.log(`Lua fixture ${script}: ${Date.now() - startedAt} ms`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, marker);
    if(cases){
      assert.match(result.stdout,new RegExp('^LUA_INTENT_ARTIFACT_DEBUFF_CASES '+cases.join(',')+'$','m'));
      gateCases.push(...cases);
    }
    assert.doesNotMatch(result.stdout, /ABYSS_FEEDBACK (?:recovered (?!cancelled)|prepare_failed|command_failed)/);
  }
  assert.deepEqual(gateCases,[1,2,3],'the two entries execute each original gate group exactly once');
});
