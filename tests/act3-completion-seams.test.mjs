import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('controlled Act3 combined-owner source group, Power order, physical flag and exhaust queue seams',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/act3_completion_seams.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT3_COMPLETION_SEAMS 13 groups; 0 failed/);
});
