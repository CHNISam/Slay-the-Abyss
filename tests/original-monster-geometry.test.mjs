import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('original monster constructor geometry and full-list drawX summon insertion',()=>{
 const result=runLua('tests/lua/original_monster_geometry.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SOURCE_MONSTER_SPAWN full-list\/delta\/dead count PASS/);
});
