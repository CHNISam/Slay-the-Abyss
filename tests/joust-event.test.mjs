import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Joust preserves five screens, exact RNG timing, payout rules and rollback',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/joust_event.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/JOUST_EVENT 6 passed/);
});
