import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('compact card rectangles are validated before allocation and lazily reuse the bounded native writer',()=>{
 const result=runLua('tests/lua/native_card_art_rectangles.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_CARD_ART_RECTANGLES_PASS/);
});
