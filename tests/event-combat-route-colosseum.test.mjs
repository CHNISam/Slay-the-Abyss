import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('controlled public Colosseum wins first fight legally and reopens instead of fabricating rewards or an exit',()=>{
 const result=runLua('tests/lua/event_combat_route_colosseum.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_COLOSSEUM_PASS/);
});
