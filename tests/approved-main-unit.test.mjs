import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {battleLayout} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
test('Main short operation strip remains at original top700 with native text height',()=>{
 const stage=battleLayout().controls.find(c=>c.name==='stage');
 const notice=stage.children.find(c=>c.name==='notice');
 assert.equal(notice.position[1],360-(700+52/2)/1.5);
 assert(notice.size[1]>=40,'native text cannot disappear below native line height');
 assertNativeUiCapacity(battleLayout());
});
test('Main runtime preserves source slots and portrait silhouettes without changing battle state',()=>{
 const r=runLua('tests/lua/approved_main_unit.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/APPROVED_MAIN_UNIT_PASS/);
});
test('Main end-turn is the original long bronze hexagon, not an invented sword button',()=>{
 const end=battleLayout().controls.find(c=>c.name==='stage').children.find(c=>c.name==='endTurn');
 const expected=[(1920-56-280/2)/1.5-640,360-(850+76/2)/1.5];
 end.position.forEach((n,i)=>assert(Math.abs(n-expected[i])<1e-9));
 assert.deepEqual(end.size,[280/1.5,76/1.5]);
 for(const state of end.children){
  assert(!state.children.some(c=>c.name==='blade'||c.name==='hilt'));
  for(const name of ['borderLeft','borderRight','plateLeft','plateRight'])assert(state.children.some(c=>c.name===name));
  assert.equal(state.children.find(c=>c.name==='label').text.fontSize,27/1.5);
 }
});
test('original Boss constructor position preserves core order, IDs and real target commands',()=>{
 const r=runLua('tests/lua/approved_main_boss_slots.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/APPROVED_MAIN_BOSS_SLOTS_PASS/);
});
