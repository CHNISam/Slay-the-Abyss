import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('original escape action gate and independent actor lifetime use real Combat and native-template controls',()=>{
 const r=runLua('tests/lua/original_monster_escape.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ORIGINAL_MONSTER_ESCAPE_PASS/);
});
