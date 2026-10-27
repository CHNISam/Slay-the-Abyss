import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('native and shared Rupture callbacks keep source TOP insertion order and rollback', () => {
  buildLuaData();
  const result = runLua('tests/lua/native_rupture_queue.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /NATIVE_RUPTURE_QUEUE 36 passed=36 failed=0/);
});
