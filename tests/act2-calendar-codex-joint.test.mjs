import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('actual Calendar/Codex held order suppresses or resumes one lethal end-turn queue',()=>{
 buildLuaData();
 const result=runLua('tests/lua/act2_calendar_codex_joint.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT2_CALENDAR_CODEX_JOINT 2 passed/);
});
