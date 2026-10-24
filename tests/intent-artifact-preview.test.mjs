import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('generated GameUI intent previews respect ordered Artifact gates without mutating combat', () => {
  buildLuaData();
  buildUI();
  const result = runLua('tests/lua/intent_artifact_preview.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_INTENT_ARTIFACT_PREVIEW 15 passed; 0 failed/);
  assert.doesNotMatch(result.stdout, /ABYSS_FEEDBACK (?:recovered (?!cancelled)|prepare_failed|command_failed)/);
});
