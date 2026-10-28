import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('exact PR266 shared revival combines with Nest through actual Nodes and permanent card hooks',()=>{
 const result=runLua('tests/lua/nest_event_tail_combination.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NEST_TAIL_COMBINATION 4 passed; controlled offline only/);
});
