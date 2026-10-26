import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('Act2 enemy intentions describe healing, cleanse and life-drain without changing combat',()=>{
 const result=runLua('tests/lua/act2_intent_ui.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);
 assert.match(result.stdout,/ACT2_INTENT_UI_PASS 10/);
});
