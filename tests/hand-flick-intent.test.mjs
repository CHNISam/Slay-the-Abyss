import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('hand gestures: upward throw plays, lateral swipe and slow lift do not',()=>{
 const result=runLua('tests/lua/hand_flick_intent.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/HAND_FLICK_INTENT_PASS 4/);
});
