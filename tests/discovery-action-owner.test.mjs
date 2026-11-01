import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Discovery keeps its existing native/shared action owner through public Run selection',()=>{
 const result=runLua('tests/lua/discovery_action_owner.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DISCOVERY_ACTION_OWNER 2 passed/);
});
