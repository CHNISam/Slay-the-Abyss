import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real host advances topbar gold on updates, not renders, and resets across runs',()=>{
 const result=runLua('tests/lua/topbar_gold_animation.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/TOPBAR_GOLD_ANIMATION_PASS/);
});
