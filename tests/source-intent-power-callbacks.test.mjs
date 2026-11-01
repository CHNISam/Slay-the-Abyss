import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source action producers explicitly refresh all displayed monster intents without status-kind heuristics',()=>{
 const r=runLua('tests/lua/source_intent_power_callbacks.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/SOURCE_INTENT_POWER_CALLBACKS_PASS 16/);
});
