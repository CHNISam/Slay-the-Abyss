import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('core dispatch keeps synchronous rejection, queue result and rollback contracts',()=>{
  const result=runLua('tests/lua/core_responsibilities.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/CORE_RESPONSIBILITIES_PASS 7/);
});

test('Act2 policy extraction preserves frozen history and typed RNG traces',()=>{
  const result=runLua('tests/lua/core_responsibilities_ai.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/CORE_AI_TRACE 1560/);
  // Measured on develop@965616d5 before extraction: 15 policies, 26 threshold
  // edges, four ally/flight/health states and 12 successive move decisions each.
  assert.equal(createHash('sha256').update(result.stdout).digest('hex'),
    'b5e7c473bc71c0b9c4494cc838ac2969b1f8a970130ca2d3999f7a9619a3a35f');
});
