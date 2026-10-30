import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Knowing Skull preserves public Nodes costs, full-slot loss, source RNG and atomic failure',()=>{
 const result=runLua('tests/lua/knowing_skull_event.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/KNOWING_SKULL_EVENT 10 passed/);
});
