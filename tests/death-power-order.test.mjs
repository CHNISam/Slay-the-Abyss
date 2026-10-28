import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source death powers keep Stasis/Corpse acquisition order in both action owners',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/death_power_order.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DEATH_POWER_ORDER 11 groups; 0 failed/);
});
