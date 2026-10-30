import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('original monster death clock and tint remain independent from action playback',()=>{
 const r=runLua('tests/lua/original_monster_death.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ORIGINAL_MONSTER_DEATH_PASS/);
});
