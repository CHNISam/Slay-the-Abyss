import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('intent formulas expose the real read-only arithmetic and preserve all owners and RNG',()=>{
 buildLuaData();buildUI();const r=runLua('tests/lua/intent_formula.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/INTENT_FORMULA_PASS 13/);
});
