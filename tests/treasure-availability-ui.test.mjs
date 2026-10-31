import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('treasure availability explains missing content and only offers existing alternatives in both UIs',()=>{
 const result=runLua('tests/lua/treasure_availability_ui.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);
 assert.match(result.stdout,/TREASURE_AVAILABILITY_UI_PASS 8/);
});
