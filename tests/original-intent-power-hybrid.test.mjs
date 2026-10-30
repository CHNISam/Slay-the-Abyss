import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual GameUI applies global source power callback using selected base and retained displayed multi',()=>{
 const r=runLua('tests/lua/original_intent_power_hybrid.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/INDEPENDENT_REAL_GUARDIAN_HYBRID_PASS/);
});
