import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('combined Ghosts Egg obtains and Writhing late-reward publication preserve shared owners',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/m3_source_union.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/M3_SOURCE_UNION 3 groups; 0 failed/);
});
