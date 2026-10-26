import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Act2 source-defined enemies run through production battle and room commands', () => {
  const result = runLua('tests/lua/act2_enemies.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_ACT2_ENEMIES_PASS 20/);
});
