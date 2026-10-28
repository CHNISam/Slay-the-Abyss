import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Act1 missing Bosses execute source A0 rules through Combat and Run rooms', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/act1_bosses.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_ACT1_BOSSES_PASS 21/);
});
