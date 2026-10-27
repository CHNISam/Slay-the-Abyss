import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('fresh exact single-use rollback ownership preserves every Run/Combat edge and standalone savepoint',()=>{
 const result=runLua('tests/lua/run_play_snapshot_owner.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/RUN_PLAY_SNAPSHOT_OWNER 9 groups; 0 failed/);
});
