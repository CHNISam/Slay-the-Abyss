import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source power callbacks drain synchronously through real feedback without extra frames or audio',()=>{
 const r=runLua('tests/lua/source_intent_power_feedback.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/SOURCE_INTENT_POWER_FEEDBACK_PASS 4/);
});
