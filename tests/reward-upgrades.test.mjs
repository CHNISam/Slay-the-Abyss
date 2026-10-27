import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('chapter rewards keep source upgrade rolls through acquisition', () => {
  const result = runLua('tests/lua/reward_upgrades.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /REWARD_UPGRADES_PASS 7/);
});
