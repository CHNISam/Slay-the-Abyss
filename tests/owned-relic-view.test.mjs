import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('owned relics remain readable with duplicates, pagination and modal boundaries', () => {
  buildLuaData(); buildUI();
  const result=runLua('tests/lua/owned_relic_view.lua');
  assert.equal(result.status,0,result.stderr+result.stdout);
  assert.match(result.stdout,/LUA_OWNED_RELIC_VIEW 2 passed/);
});
