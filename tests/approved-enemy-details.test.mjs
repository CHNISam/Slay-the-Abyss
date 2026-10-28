import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('approved unit details retain complete information and command priority',()=>{
 const result=runLua('tests/lua/approved_enemy_details.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/APPROVED_ENEMY_DETAILS_PASS 2/);
});
