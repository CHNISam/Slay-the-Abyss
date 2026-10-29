import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('battle presentation preserves event order, rules and bounded native controls through interruption', () => {
  const result = runLua('tests/lua/battle_life_regression.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_BATTLE_LIFE_REGRESSION_PASS 6/);
});
