import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source power refresh reads selected damage without executing future effects; recovery preserves clocks',()=>{
 const result=runLua('tests/lua/monster_intent_refresh_boundaries.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MONSTER_INTENT_REFRESH_BOUNDARIES PASS/);
});
