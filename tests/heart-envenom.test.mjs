import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Heart Invincible gates Envenom construction without preview budget consumption',()=>{
 const result=runLua('tests/lua/heart_envenom.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/HEART_ENVENOM_PASS 4/);
});
