import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

for (const [slice,groups] of [['discard',4],['turn',4],['finish',3]]) test(`nested discard/end-turn ${slice} preserves full single-use rollback ownership`,()=>{
 const result=runLua(`tests/lua/run_nested_snapshot_owner${slice==='discard'?'':`_${slice}`}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.ok(result.stdout.includes(`RUN_NESTED_SNAPSHOT_OWNER ${slice} ${groups} groups; 0 failed`),result.stdout);
});
