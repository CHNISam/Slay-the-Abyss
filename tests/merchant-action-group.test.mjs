import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('grouped merchant purchase actions preserve mouse and touch trade and dialogue',()=>{
 const r=runLua('tests/lua/merchant_action_group.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/MERCHANT_ACTION_GROUP_PASS/);
});
