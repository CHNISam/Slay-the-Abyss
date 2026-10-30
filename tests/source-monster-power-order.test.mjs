import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('original monster Power membership, constructor append and stable action order',()=>{
 const result=runLua('tests/lua/source_monster_power_order.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SOURCE_MONSTER_POWER_ORDER 20 groups passed/);
});
test('current 42 original enemy constructors, turn lists and detached frames have verified flags',()=>{
 const result=runLua('tests/lua/source_monster_power_roster.lua',{timeout:120000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SOURCE_MONSTER_POWER_ROSTER 42 actors passed/);
});
