import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('boss entrance expires once without clobbering newer feedback',()=>{
 const r=runLua('tests/lua/boss_entrance_notice.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/BOSS_ENTRANCE_NOTICE_PASS/);
});
