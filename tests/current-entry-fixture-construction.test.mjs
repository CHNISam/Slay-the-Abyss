import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('trusted fixture construction avoids redundant guards while returned native controls remain strict and independent',()=>{
 const r=runLua('tests/lua/fixture_constructor_guards.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/FIXTURE_CONSTRUCTOR_GUARDS_PASS/);
});
