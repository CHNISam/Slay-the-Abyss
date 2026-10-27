import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Guardian reactions preserve pending completion and settle completed tails',()=>{
  const result=runLua('tests/lua/guardian_reaction_completion.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/Guardian reaction completion: 2 passed, 0 failed/);
});
