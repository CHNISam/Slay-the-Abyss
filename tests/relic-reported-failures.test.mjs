import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('reported event, Helix and Pantograph rewards actually work',()=>{
 const result=runLua('tests/lua/relic_reported_failures.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/REPORTED_RELIC_FAILURES_PASS 7/);
});
