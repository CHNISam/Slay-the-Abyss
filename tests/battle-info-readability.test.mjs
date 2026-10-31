import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('live GameUI separates floor, full-bleed intent and powers from potion/body/HP',()=>{
 const r=runLua('tests/lua/battle_info_readability.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/BATTLE_INFO_READABILITY_PASS/);
});
