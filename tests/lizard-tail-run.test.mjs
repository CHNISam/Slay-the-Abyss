import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Lizard Tail actual obtain and fatal coordinator preserve reserve order and persistent owners',()=>{
 const r=runLua('tests/lua/lizard_tail_run.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/LIZARD_TAIL_RUN_PASS 8 groups; controlled\/offline only/);
});
