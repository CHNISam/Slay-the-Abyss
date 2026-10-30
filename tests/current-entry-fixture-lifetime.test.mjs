import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('current entry worlds return to baseline through real teardown and reject stale control access',()=>{
 buildLuaData();buildUI();
 const r=runLua('tests/lua/support/current_entry_fixture_contract.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CURRENT_ENTRY_FIXTURE_LIFETIME_PASS 8/);
});
