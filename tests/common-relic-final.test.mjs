import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('remaining common relics execute elite/HP-loss/heal/unknown-room/rest hooks', () => {
  buildLuaData();
  const result = runLua('tests/lua/common_relic_final.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_COMMON_RELIC_FINAL_PASS 8/);
});
