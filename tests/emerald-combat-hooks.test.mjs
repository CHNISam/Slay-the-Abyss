import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real combat applies burning elite boosts and source monster regeneration once',()=>{
 const result=runLua('tests/lua/emerald_combat_hooks.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/EMERALD_COMBAT_HOOKS_PASS 5/);
});
