import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('normal full-pool reward preserves unavailable identity without blocking the UI',()=>{
 const result=runLua('tests/lua/reward_source_ui.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);
 assert.match(result.stdout,/REWARD_SOURCE_UI_PASS 2/);
});
