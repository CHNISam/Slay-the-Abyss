import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('all 42 two-act enemies use native numeric images through battle SetImage, including bosses and summons', () => {
  const result = runLua('tests/lua/native_enemy_portraits.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_NATIVE_ENEMY_PORTRAITS_PASS 42 \+ summons \+ unknown fallbacks/);
});
