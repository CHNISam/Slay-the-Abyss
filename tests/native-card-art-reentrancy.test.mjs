import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('native card art owns late handles and cancels reentrant create/write/cleanup callbacks',()=>{
 const result=runLua('tests/lua/native_card_art_reentrancy.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_CARD_ART_REENTRANCY_MATRIX_PASS 36/);
});
