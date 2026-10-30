import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('current Matryoshka and Cursed Key obtain/open hooks preserve independent reward, key and RNG ownership',()=>{
 buildLuaData();const result=runLua('tests/lua/sapphire_current_relics.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SAPPHIRE_CURRENT_RELICS_PASS/);
});
