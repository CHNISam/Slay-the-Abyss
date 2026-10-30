import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual enemy queues preserve displayed intent through roll and reset even an identical move at player turn',()=>{
 const r=runLua('tests/lua/original_intent_roll_boundary.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/INDEPENDENT_REAL_ROLL_BOUNDARY_PASS/);
});
