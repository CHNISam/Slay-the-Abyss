import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('competition Neow keeps source floor eligibility within the same Host only',()=>{
 const result=runLua('tests/lua/neow_session_qualification.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NEOW_SESSION_QUALIFICATION_PASS/);
});
