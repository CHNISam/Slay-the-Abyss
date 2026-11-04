import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('drag reading bounds preserve ownership and commands for the first four input/viewport cases',()=>{
 const result=runLua('tests/lua/touch_card_reading_bounds.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/TOUCH_CARD_READING_BOUNDS_PASS 4 SIZES 1-2/);
});
test('drag reading bounds preserve ownership and commands for the remaining four input/viewport cases',()=>{
 const result=runLua('tests/lua/touch_card_reading_bounds_slice_2.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/TOUCH_CARD_READING_BOUNDS_PASS 4 SIZES 3-4/);
});
