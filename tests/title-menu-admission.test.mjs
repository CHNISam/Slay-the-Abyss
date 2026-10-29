import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('approved title omits initial speed selection',()=>{
 const menu=gameLayout().controls.find(c=>c.name==='menuPanel');
 assert(menu&&!menu.children.some(c=>c.name==='battleSpeed'));
});
test('route menu native enabled states and commands share real run and opening admission',()=>{
 const r=runLua('tests/lua/title_menu_admission.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/TITLE_MENU_ADMISSION_PASS 4/);
});
