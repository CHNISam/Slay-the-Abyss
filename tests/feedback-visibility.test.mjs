import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('real flying Defend leaves HP and Block above the card while foreground feedback and cancellation survive', () => {
  buildLuaData();
  buildUI();
  const result = runLua('tests/lua/feedback_visibility.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_FEEDBACK_VISIBILITY_PASS 6 layouts/);
});
