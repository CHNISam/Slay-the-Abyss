import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('Boot, Akabeko, Pen Nib and Nunchaku execute actual attack/preview/rollback paths', () => {
  buildLuaData();
  const result = runLua('tests/fixtures/js-owned/tests/lua/common_relic_attacks.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_COMMON_RELIC_ATTACKS_PASS 6/);
});
