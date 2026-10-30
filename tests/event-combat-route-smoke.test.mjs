import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real Smoke reopens the first Colosseum and real Masked Bandits offers respect held-mask ownership',()=>{
 const result=runLua('tests/lua/event_combat_route_smoke.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_SMOKE_PASS/);
});
