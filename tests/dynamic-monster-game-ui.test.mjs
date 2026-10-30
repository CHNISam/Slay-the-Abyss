import test from 'node:test';
import assert from 'node:assert/strict';
import {monsterEnabledLua} from './helpers/monster-enabled-ui.mjs';
const runLua=monsterEnabledLua();
test('actual generated GameUI renders six complete source-bound monster instances and retires them',()=>{
 const r=runLua('tests/lua/support/dynamic_monster_game_ui.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/DYNAMIC_MONSTER_GAME_UI_PASS/);
 assert.match(r.stdout,/DYNAMIC_MONSTER_GAME_UI_ROLLBACK_PASS/);
});
