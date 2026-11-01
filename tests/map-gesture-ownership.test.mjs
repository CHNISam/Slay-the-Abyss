import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('map gestures preserve exit cancellation and input ownership in generated native UI', () => {
  buildLuaData();
  buildUI();
  const result = runLua('tests/lua/map_gesture_ownership.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MAP_GESTURE_OWNERSHIP 39 passed; 0 failed/);
});
