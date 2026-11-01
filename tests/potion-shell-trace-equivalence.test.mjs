import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('potion shell extraction preserves every native call across empty, known, unknown and selection states',()=>{
 const result=runLua('tests/lua/potion_shell_trace_equivalence.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/POTION_SHELL_TRACE_EQUIVALENCE 90 cases passed/);
});
