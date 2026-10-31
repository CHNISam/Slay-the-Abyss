import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { potionSlotVisual } from '../scripts/potion-slot-visual.mjs';
import { runLua } from '../scripts/test-lua.mjs';
const child=(c,n)=>c.children.find(v=>v.name===n);
const entry=n=>child(gameLayout().controls.find(c=>c.name===n),'open');
const states=['normal','hover','pressed','disabled'];

test('deck entry is an STS-style fanned card stack with a same-ink count pip inside the menu-sibling disc',()=>{
  const open=entry('deckEntry'),hit=child(open,'hit');
  assert.equal(hit.kind,'presetButton');assert.equal(hit.focusable,true);
  assert.deepEqual(open.size,[80,48]);
  for(const name of states){
    const state=child(hit,name);
    const cards=['back2','back1','front'].map(n=>child(state,n));
    for(const card of cards){
      assert.equal(card.kind,'container');
      assert.ok(card.size[1]>card.size[0],'card silhouettes are portrait rectangles');
      assert.deepEqual(card.children.map(c=>c.name),['border','plate']);
    }
    assert.ok(cards[0].rotation>cards[1].rotation&&cards[1].rotation>cards[2].rotation,'stack fans out behind the front card');
    assert.equal(state.children.some(c=>c.name==='badge'),false,'no stray dark badge plate');
    for(const c of [...cards,child(state,'ring'),child(state,'count')]){
      const [x,y]=c.position,[w,h]=c.size;
      assert.ok(Math.abs(x)+w/2<=40&&Math.abs(y)+h/2<=24,c.name+' stays inside the 80x48 hit');
    }
    assert.equal(child(state,'deckIcon').image,theme.icon.deck.id);
    assert.equal(child(state,'ring').image,theme.image.disc);
    assert.equal(child(state,'ring').size[0],theme.layout.exitMenu.entryVisual.diameter,'deck disc is the 菜单 sibling');
    assert.equal(child(state,'label').visible,false,'retain only a hidden compatibility caption');
    assert.equal(child(state,'count').kind,'text');
  }
  assert.match(readFileSync('src/lua/abyss_game_ui.lua','utf8'),/GetChild\('count'\)\.text=run and number\(#run\.deck\)/);
});

test('nonbattle potion entry uses physical circular silhouettes without creating new actions',()=>{
  const open=entry('potionEntry'),hit=child(open,'hit');
  assert.equal(open.children.length,1);assert.equal(hit.kind,'presetButton');assert.equal(hit.focusable,true);
  for(const name of states){
    const state=child(hit,name);assert.equal(child(state,'label').visible,false);
    assert.equal(state.children.filter(c=>/^slot[1-5]$/.test(c.name)).length,5);
    assert.ok(state.children.every(c=>c.kind==='container'||c.name==='label'),'no rectangular background on the entire strip');
    for(let i=1;i<=5;i++){
      const slot=child(state,`slot${i}`);
      assert.deepEqual(slot.size,[34.667,34.667]);
      assert.equal(child(slot,'border').image,theme.image.disc);assert.equal(child(slot,'plate').image,theme.image.disc);
      assert.deepEqual(child(slot,'bottle').size,[16,16]);
      assert.equal(child(slot,'bottle').image,theme.icon.potion.fire_potion);
      assert.equal(child(slot,'bottle').visible,false);
      assert.equal(slot.children.some(c=>c.kind==='cursorArea'||c.kind==='presetButton'),false,'slots are not new use buttons');
    }
  }
});

test('real potion header repaint preserves physical capacity and sparse inventory without mutating it',()=>{
  buildLuaData();buildUI();
  const result=runLua('tests/lua/map_utility_header.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/MAP_UTILITY_HEADER_PASS/);
});

// Main keeps compatibility paths, but they cannot show the rejected solid empty shell.
test('shared slot helper retains hidden Main compatibility paths without mutating inputs',()=>{
  const border={name:'border',kind:'image',position:[0,0],size:[34.667,34.667],image:theme.image.rect,colour:theme.color.gold};
  const plate={name:'plate',kind:'image',position:[0,0],size:[30.667,30.667],image:theme.image.rect,colour:theme.color.panelRaised};
  const children=potionSlotVisual(theme,{border,plate,bottleSize:16,ink:theme.color.goldBright});
  assert.deepEqual(children.slice(0,2),[{...border,image:theme.image.disc,visible:false},{...plate,image:theme.image.disc,visible:false}]);
  assert.deepEqual(children.map(c=>c.name),['border','plate','selectedShell','emptyShell','filledShell','fireShell','bottle']);
  assert.equal(border.image,theme.image.rect);assert.equal(plate.image,theme.image.rect);
});
