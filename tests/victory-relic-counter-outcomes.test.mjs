import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('public escape and defeat preserve existing counter behavior',()=>{
 const result=runLua('tests/lua/victory_relic_counter_outcomes.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/VICTORY_RELIC_COUNTER_OTHER_OUTCOMES_PASS/);
});
