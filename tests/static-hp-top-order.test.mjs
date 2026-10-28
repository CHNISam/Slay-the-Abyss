import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Static/Puzzle HP reactions retain source TOP order on existing managers',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/static_hp_top_order.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/STATIC_HP_TOP_ORDER 13 groups; 0 failed/);
});
