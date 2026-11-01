import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('unverified result duration cannot leak or prevent restart and settlement',()=>{
 const r=runLua('tests/lua/result_duration_unavailable.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RESULT_DURATION_UNAVAILABLE_PASS/);
});
