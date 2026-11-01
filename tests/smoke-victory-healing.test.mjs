import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('public normal Smoke performs four source victory heals and actual Flower/Bloom modifiers',()=>{
 const result=runLua('tests/lua/smoke_victory_healing.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/SMOKE_VICTORY_HEALING_MATRIX_PASS 6/);
});
