import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('late public lethal reward failure restores counters/resources/whole original graph and retry commits once',()=>{
 const result=runLua('tests/lua/victory_relic_counter_rollback.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/VICTORY_RELIC_COUNTER_ROLLBACK_PASS/);
});
