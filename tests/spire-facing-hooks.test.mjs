import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real Spire facing, source intent math and death cleanup preserve transactional input',()=>{
 const result=runLua('tests/lua/spire_facing_hooks.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SPIRE_FACING_HOOKS_PASS 10/);
});
