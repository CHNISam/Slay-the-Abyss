import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('public normal and elite lethal play preserves the whole command transaction',()=>{
 const result=runLua('tests/lua/run_play_transactions.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/RUN_PLAY_TRANSACTIONS 5 groups; 0 failed/);
});
