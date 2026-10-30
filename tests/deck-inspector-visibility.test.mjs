import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('strict native inspector visibility is boolean for unset false and true browse flags',()=>{
 const result=runLua('tests/lua/deck_inspector_visibility.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DECK_INSPECTOR_VISIBILITY_PASS nil false true and normal browse/);
});
