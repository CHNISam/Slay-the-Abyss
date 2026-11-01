import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('ordinary hand cards expose full effects on hold without play or stale UID reuse',()=>{
 const r=runLua('tests/lua/r2_hand_help.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/R2_HAND_HELP_PASS/);
});
