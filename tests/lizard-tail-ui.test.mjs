import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('the existing battle portrait details expose live Tail state as a readonly relic section',()=>{
 const result=runLua('tests/lua/lizard_tail_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LIZARD_TAIL_UI_PASS 6/);
});
