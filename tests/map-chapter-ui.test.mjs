import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('chapter-local map geometry, real same-table transitions and stale gestures preserve core state', () => {
  buildLuaData();
  buildUI();
  const result = runLua('tests/lua/map_chapters.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MAP_CHAPTERS_PASS 31/);
});
