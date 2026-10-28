import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real native and advanced card queues retain Heart Beat with source damage and physical-card rules',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/heart_after_use.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/HEART_AFTER_USE_PASS 8/);
});
