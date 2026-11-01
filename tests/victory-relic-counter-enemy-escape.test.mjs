import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual Looter all-enemies escape dispatches source endBattle cleanup without clearing permanent counters',()=>{
 const result=runLua('tests/lua/victory_relic_counter_enemy_escape.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/VICTORY_RELIC_COUNTER_ENEMY_ESCAPE_PASS/);
});
