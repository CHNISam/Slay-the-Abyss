import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('competition same-host Boss restart gains four offers while a fresh host and early death retain two',()=>{
 const result=runLua('tests/lua/neow_competition_restart.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NEOW_COMPETITION_RESTART_PASS first2 boss4 newHost2 earlyDeath2/);
});
