import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('native actor surfaces follow every drawable identity without a static visibility cap',()=>{
 const r=runLua('tests/lua/dynamic_monster_surfaces.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/DYNAMIC_MONSTER_SURFACES_PASS/);
});
