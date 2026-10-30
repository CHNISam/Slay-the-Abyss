import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('native power chips preserve unlimited source order and exact owned lifecycle',()=>{
 const r=runLua('tests/lua/dynamic_monster_power_surfaces.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/DYNAMIC_MONSTER_POWER_SURFACES_PASS/);
});
