import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('fatal HP-loss callbacks preserve pinned source Fairy/Bloom ordering on every owner', () => {
  buildLuaData();
  const result = runLua('tests/fixtures/js-owned/tests/lua/fatal_hp_loss_callbacks.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /FATAL_HP_LOSS_CALLBACKS 31 passed=31 failed=0/);
});
