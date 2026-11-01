import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual particle destruction failure cannot skip actor input retirement and remains retryable',()=>{
 const r=runLua('tests/lua/monster_intent_cleanup_failure.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/MONSTER_INTENT_CLEANUP_FAILURE_PASS/);
});
