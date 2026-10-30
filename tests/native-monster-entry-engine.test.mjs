import test from 'node:test';
import assert from 'node:assert/strict';
import {buildUI} from '../scripts/build-ui.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('explicit native entry engine clones real OFF templates and preserves failure/lifecycle boundaries',()=>{
 buildLuaData();buildUI();
 const result=runLua('tests/lua/support/native_monster_engine_contract.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_MONSTER_ENTRY_ENGINE_PASS/);
});
