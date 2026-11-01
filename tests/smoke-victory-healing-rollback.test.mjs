import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('failed late Smoke healing leaves full live graph/bottle intact and retry heals only once',()=>{
 const result=runLua('tests/lua/smoke_victory_healing_rollback.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/SMOKE_VICTORY_HEALING_ROLLBACK_PASS/);
});
