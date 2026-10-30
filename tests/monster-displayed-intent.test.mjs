import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source displayed intent preserves copied enum/multi while applyPowers uses current selected base damage',()=>{
 const r=runLua('tests/lua/monster_displayed_intent.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/MONSTER_DISPLAYED_INTENT_SOURCE_PASS/);
});
