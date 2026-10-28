import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('Happy Flower, Ancient Tea Set and Art of War dispatch in actual combat turns with persistent counters', () => {
  buildLuaData();
  const result = runLua('tests/fixtures/js-owned/tests/lua/common_relic_turns.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_COMMON_RELIC_TURNS_PASS 5/);
});
