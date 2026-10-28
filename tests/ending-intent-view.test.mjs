import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Act4 intent details retain source actions without mutating combat or RNG',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/ending_intent_view.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_INTENT_VIEW_PASS 5/);
});
test('Act4 intent tooltip remains readable through generated strict native controls and pagination',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/ending_intent_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_INTENT_UI_PASS 3/);
});
