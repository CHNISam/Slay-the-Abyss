import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Cleric Smoke publishes consistent Run/escaped actor/map HUD and next public battle health',()=>{
 const result=runLua('tests/lua/smoke_victory_healing_hud.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/SMOKE_VICTORY_HEALING_HUD_PASS/);
});
