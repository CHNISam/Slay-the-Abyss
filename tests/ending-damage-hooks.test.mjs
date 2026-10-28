import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real Actor preserves Heart damage budget, owner-turn reset, preview and source Painful Stabs',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/ending_damage_hooks.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_DAMAGE_HOOKS_PASS 5/);
});
