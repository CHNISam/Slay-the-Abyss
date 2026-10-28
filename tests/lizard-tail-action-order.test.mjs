import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('independent Lizard Tail real native/forced card queues preserve fatal callback action order',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/lizard_tail_action_order.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LIZARD_TAIL_ACTION_ORDER_PASS 4 groups; controlled offline/);
});
