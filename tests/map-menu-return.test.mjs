import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('map menu admission and one-back route previews preserve caller and pointer ownership',()=>{
 const result=runLua('tests/lua/map_menu_return.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MAP_MENU_RETURN_PASS 3/);
});
