import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const kind of ['pile','pile_fairy','discard','scry','hand'])test(`public ${kind} continuation restores the complete Run graph after late finish failure`,()=>{
 const result=runLua(`tests/lua/run_choice_transactions${kind==='pile'?'':'_'+kind}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.ok(result.stdout.includes(`RUN_CHOICE_TRANSACTIONS ${kind} ${kind==='pile'?4:2} groups; 0 failed`),result.stdout);
});
