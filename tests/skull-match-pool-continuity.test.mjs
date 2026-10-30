import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Match and Knowing Skull share canonical act-wide order across both directions and rollback',()=>{
 const result=runLua('tests/lua/skull_match_pool_continuity.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SKULL_MATCH_POOL_CONTINUITY 4 passed/);
});
