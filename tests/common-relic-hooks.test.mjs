import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('eight common relics execute source hooks through permanent and combat boundaries', () => {
  buildLuaData();
  const result = runLua('tests/fixtures/js-owned/tests/lua/common_relic_hooks.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_COMMON_RELIC_HOOKS_PASS 9/);
});
