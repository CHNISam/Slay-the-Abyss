import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('ending enemy source plans execute through real Combat lifecycle and existing queues',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/ending_enemy_runtime.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_ENEMY_RUNTIME_PASS 10 groups; real lifecycle\/actions only/);
});
