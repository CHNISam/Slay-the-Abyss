import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
test('battle topbar retains separate floor chip and approved HP/gold colours',()=>{
 const panel=gameLayout().controls.find(c=>c.name==='battlePanel');
 const child=name=>panel.children.find(c=>c.name===name);
 assert.ok(child('floorIcon')&&child('floor'));
 assert.deepEqual(child('player').text.colour,nativeTheme.color.topPanelHp);
 assert.deepEqual(child('piles').text.colour,nativeTheme.color.topPanelGold);
});
test('real host shows exact gold after one render, idle updates and run replacement',()=>{
 const r=runLua('tests/lua/topbar_gold_exact.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/TOPBAR_GOLD_EXACT_PASS/);
});
