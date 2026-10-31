import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('five common equipment and room/potion effects retain source values and random consumption', () => {
  buildLuaData();
  const result = runLua('tests/lua/common_relic_equipment.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_COMMON_RELIC_EQUIPMENT_PASS 8\b/);
});
