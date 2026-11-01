import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('max HP acquisition reads actual public battle health and preserves the complete rollback/Tail graph',()=>{
 const result=runLua('tests/lua/max_hp_current_owners.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MAX_HP_CURRENT_OWNERS_PASS 4 controlled\/offline only/);
});
