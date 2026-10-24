import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('real Run and generated host use the original reward-list / card-picker lifecycle', () => {
  const result = runLua('tests/lua/reward_flow_parity.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
