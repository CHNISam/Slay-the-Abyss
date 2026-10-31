import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('animated hover retains world pointer bounds through safe-clamped lift and return for 1/5/10 cards',()=>{
  const result=runLua('tests/lua/hand_hover_hit_bounds.lua',{timeout:30000});
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_HAND_HOVER_HIT_BOUNDS_PASS/);
});
