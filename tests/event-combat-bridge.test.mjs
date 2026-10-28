import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real source event combats preserve constructor and reward transaction ownership',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/event_combat_bridge.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/EVENT_COMBAT_BRIDGE_PASS/);
});
