import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('current native menu pointer, controller and settlement boundaries',()=>{
 const result=runLua('tests/lua/menu_input_boundaries_current.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MENU_INPUT_BOUNDARIES_CURRENT_PASS 3/);
});
