import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('formal Heart finish and explicit owner-bound Proceed preserve reward and rollback boundaries',()=>{
 const result=runLua('tests/lua/ending_route_api.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_ROUTE_API_PASS 3 groups/);
});
