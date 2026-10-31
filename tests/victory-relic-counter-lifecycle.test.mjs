import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('public victory reward/map hides seven battle counters, preserves permanent counters and resets next combat',()=>{
 const result=runLua('tests/lua/victory_relic_counter_lifecycle.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/VICTORY_RELIC_COUNTER_LIFECYCLE_PASS 7/);
});
