import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Donu and Deca retain A0 group action order, Artifact, RNG and one reward', () => {
  const result = runLua('tests/lua/donu_deca.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_DONU_DECA_PASS 14/);
});
