import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('Orb Walker runs through real Act3 room, source streams and atomic battle commands',()=>{
  const result=runLua('tests/lua/act3_orb_walker.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ACT3_ORB_WALKER 12 passed; 0 failed/);
});
