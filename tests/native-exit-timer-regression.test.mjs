import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('native unavailable clock permits exit cancellation, restart and a deduplicated settlement retry',()=>{
  const result=runLua('tests/lua/native_exit_timer_regression.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_EXIT_TIMER_RESTART_PASS/);
  assert.match(result.stdout,/NATIVE_EXIT_TIMER_RETRY_PASS/);
});
