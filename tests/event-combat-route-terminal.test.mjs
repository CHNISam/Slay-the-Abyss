import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('public potion-command victories settle Mask/Circlet and second Colosseum rewards once then return to usable map',()=>{
 const result=runLua('tests/lua/event_combat_route_terminal.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_TERMINAL_PASS/);
});
