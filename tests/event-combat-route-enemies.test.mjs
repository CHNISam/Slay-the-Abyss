import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('event constructors and AI use source streams and legal public turns without combat stat injection',()=>{
 const result=runLua('tests/lua/event_combat_route_enemies.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_ENEMIES_PASS/);
});
