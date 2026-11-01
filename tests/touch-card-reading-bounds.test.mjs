import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('drag reading frames stay inside safe bounds without changing pointer ownership or commands',()=>{
 const result=runLua('tests/lua/touch_card_reading_bounds.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/TOUCH_CARD_READING_BOUNDS_PASS 8/);
});
