import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source mandatory event grids keep candidate/order/identity and interrupted native ownership',()=>{
 const result=runLua('tests/lua/event_card_picker_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/EVENT_CARD_PICKER_UI 5 passed/);
});
