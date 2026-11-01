import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('native portrait receives real hero idle/attack/cancel motion while gameplay and HUD stay unchanged',()=>{
 const result=runLua('tests/lua/support/official_portrait_feedback.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/OFFICIAL_PORTRAIT_FEEDBACK_PASS/);
});
