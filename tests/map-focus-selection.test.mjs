import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('choosing a breathing map room keeps focus immediately visible and fully inside the viewport',()=>{
 const result=runLua('tests/lua/map_focus_selection.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MAP_FOCUS_SELECTION_PASS 24/);
});
