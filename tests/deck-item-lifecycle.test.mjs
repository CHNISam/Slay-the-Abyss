import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('deck and relic views tolerate native item retirement and reject stale item callbacks',()=>{
 const result=runLua('tests/lua/deck_item_lifecycle.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DECK_ITEM_LIFECYCLE_PASS 4/);
});
