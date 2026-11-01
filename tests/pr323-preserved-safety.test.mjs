import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('six PR323 regressions retain 807 input origin, cancellation, admission and active health ownership',()=>{
 const result=runLua('tests/lua/pr323_preserved_safety.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/PR323_PRESERVED_SAFETY_PASS 6 FAIL 0/);
});
