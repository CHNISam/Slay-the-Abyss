import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('one through five actor encounters and supported boss groups retain visible compound intentions without covering notice or potions',()=>{
 const result=runLua('tests/lua/intent_face_clearance.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/INTENT_FACE_CLEARANCE_PASS normal\/elite\/boss 1\.\.5/);
});
