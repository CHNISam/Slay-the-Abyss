import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('result duration fails closed for invalid data and the unverified native public clock',()=>{
  const result=runLua('tests/lua/game_ui_timer_safety.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/TIMER_VALUE_SAFETY_PASS/);
  assert.match(result.stdout,/NATIVE_TIMER_FALLBACK_PASS/);
});
