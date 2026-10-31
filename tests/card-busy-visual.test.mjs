import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('battle cards show rule playability while busy and overlay still reject commands',()=>{
 const result=runLua('tests/lua/card_busy_visual.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CARD_BUSY_VISUAL_PASS/);
});
