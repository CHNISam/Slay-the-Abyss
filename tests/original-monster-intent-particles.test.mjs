import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('original unknown/stun particles retain independent uncapped source lifecycles and cosmetic RNG',()=>{
 const r=runLua('tests/lua/monster_intent_particles.lua');assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SOURCE_INTENT_PARTICLES_PASS/);
});
