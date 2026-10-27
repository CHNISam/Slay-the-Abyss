import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Plated Armor source actions compose with native, advanced and V4 queues', () => {
  const result = runLua('tests/lua/plated_armor_queue.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_PLATED_ARMOR_QUEUE_PASS 49\b/);
});
