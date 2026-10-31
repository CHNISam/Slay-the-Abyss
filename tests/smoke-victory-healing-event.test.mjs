import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual event Smoke heals once in Meat/held relic order and reopens its real event',()=>{
 const result=runLua('tests/lua/smoke_victory_healing_event.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/SMOKE_VICTORY_HEALING_EVENT_PASS/);
});
