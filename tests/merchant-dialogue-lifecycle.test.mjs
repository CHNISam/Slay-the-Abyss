import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('merchant delayed taps and transaction gestures follow the visible dialogue lifecycle',()=>{
 const r=runLua('tests/lua/merchant_dialogue_lifecycle.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
});
