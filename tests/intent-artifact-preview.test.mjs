import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('generated GameUI intent previews respect ordered Artifact gates without mutating combat', () => {
  buildLuaData();
  buildUI();
  // Independent concerns retain the runner's unchanged per-script deadline.
  for (const [script, marker] of [
    ['tests/lua/intent_artifact_preview.lua', /^LUA_INTENT_ARTIFACT_PREVIEW 12 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_playback.lua', /^LUA_INTENT_ARTIFACT_PLAYBACK 1 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_charges.lua', /^LUA_INTENT_ARTIFACT_CHARGES 1 passed; 0 failed$/m],
    ['tests/lua/intent_artifact_cancellation.lua', /^LUA_INTENT_ARTIFACT_CANCELLATION 1 passed; 0 failed$/m],
  ]) {
    const result = runLua(script);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, marker);
    assert.doesNotMatch(result.stdout, /ABYSS_FEEDBACK (?:recovered (?!cancelled)|prepare_failed|command_failed)/);
  }
});
