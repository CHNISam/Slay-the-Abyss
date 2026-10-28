import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('HP-loss reactive hooks preserve source actions under native and shared owners', () => {
  buildLuaData();
  const result = runLua('tests/fixtures/js-owned/tests/lua/hp_loss_action_boundaries.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /HP_LOSS_ACTION_BOUNDARIES 36 passed=36 failed=0/);
});
