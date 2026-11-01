import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('approved cinematic leads into fresh-start Neow and replays neither film nor persistent history',()=>{
 buildLuaData();buildUI();
 const r=runLua('tests/lua/approved_opening.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/APPROVED_OPENING_PASS 1/);
});
