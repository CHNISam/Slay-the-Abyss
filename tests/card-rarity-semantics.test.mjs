import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('premium chrome preserves rarity and official icon contrast across shared card faces',()=>{
 const result=runLua('tests/lua/card_rarity_semantics.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_CARD_RARITY_SEMANTICS_PASS/);
});
