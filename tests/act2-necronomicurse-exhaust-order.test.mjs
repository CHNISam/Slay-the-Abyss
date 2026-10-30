import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source CardGroup relic/power/card order survives actual TrueGrit with/without Powers and native exhaust owner',()=>{
 const r=runLua('tests/lua/act2_necronomicurse_exhaust_order.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ACT2_NECRONOMICURSE_EXHAUST_ORDER 3 passed/);
});
