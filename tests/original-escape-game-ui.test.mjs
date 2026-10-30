import test from 'node:test';
import assert from 'node:assert/strict';
import {monsterEnabledLua} from './helpers/monster-enabled-ui.mjs';
const runLua=monsterEnabledLua();
test('real GameUI forwards source escape flip/movement and keeps source HUD hidden across rerenders',()=>{
 const r=runLua('tests/lua/support/original_escape_game_ui.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ORIGINAL_ESCAPE_GAME_UI_PASS/);
});
