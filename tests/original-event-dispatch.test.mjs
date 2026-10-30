import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('all originally eligible first-two-act source identities have real registered dispatch, without source narrowing',()=>{
 const result=runLua('tests/lua/original_event_dispatch.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ORIGINAL_EVENT_DISPATCH_PASS 42 identities/);
});
