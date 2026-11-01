import test from 'node:test';import assert from 'node:assert/strict';
import {battleLayout,theme} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const stage=()=>battleLayout().controls.find(x=>x.name==='stage');
const potion=(s,i)=>i<4?s.children.find(c=>c.name==='potion'+i):s.children.find(c=>c.name==='potionHelp').children.find(c=>c.name==='potion'+i);
test('Readable potion row preserves all five physical circular potion slots with official bottles and no old text row',()=>{
 const s=stage();for(let i=1;i<=5;i++){
  const p=potion(s,i);const expected=[-100+(i-1)*48,264];p.position.forEach((n,a)=>assert(Math.abs(n-expected[a])<1e-9));
  assert.deepEqual(p.size,[44,44]);
  assert.ok(Math.abs(p.position[0])+p.size[0]/2<=640&&Math.abs(p.position[1])+p.size[1]/2<=360,'bottle stays inside base canvas');
  if(i>1)assert.ok(p.position[0]-p.size[0]/2-(potion(s,i-1).position[0]+potion(s,i-1).size[0]/2)>=4,'physical bottle targets keep their gap');
  for(const state of p.children){assert.equal(state.children.find(c=>c.name==='plate').image,theme.image.disc);assert.equal(state.children.find(c=>c.name==='border').image,theme.image.disc);assert(state.children.find(c=>c.name==='bottle'));assert.equal(state.children.find(c=>c.name==='label').visible,false);}
 }
 assertNativeUiCapacity(battleLayout());
});
test('Main potion popup is a compact anchored effect card with explicit use and discard actions',()=>{
 const s=stage(),group=s.children.find(c=>c.name==='potionHelp'),p=group.children.find(c=>c.name==='potionPopup');assert(p,'reuse existing parent capacity');
 assert.equal(p.visible,false);for(const name of ['title','target','effect','use','discard','hit'])assert(p.children.find(c=>c.name===name),name);
 assert.deepEqual(p.size,[400,180]);assert.deepEqual(p.position,[-100,150]);
 assert.equal(p.position[1]+p.size[1]/2,240);
 assert.ok(potion(s,1).position[1]-potion(s,1).size[1]/2-(p.position[1]+p.size[1]/2)>=2,'popup remains below the bottle row');
 assert.ok(Math.abs(p.position[0])+p.size[0]/2<=640&&Math.abs(p.position[1])+p.size[1]/2<=360,'initial popup stays inside base canvas');
});

test('Main potion runtime preserves explicit actions, stale ownership, and the real Potion Belt fifth slot',()=>{
 const r=runLua('tests/lua/approved_main_potions.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/APPROVED_MAIN_POTIONS_PASS/);
});
test('Main host isolates the small potion card controller scope and keeps global inventory off battle',()=>{
 const r=runLua('tests/lua/approved_main_host_potions.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/APPROVED_MAIN_HOST_POTIONS_PASS/);
});

test('Main popup initial dismiss remains centered on the entire canvas before first render',()=>{
 const p=stage().children.find(c=>c.name==='potionHelp').children.find(c=>c.name==='potionPopup');
 const d=p.children.find(c=>c.name==='dismiss');
 assert.deepEqual(d.size,theme.canvas.base);
 d.position.forEach((n,i)=>assert(Math.abs(n+p.position[i])<1e-8));
});
test('Main popup action labels retain a native text line inside the source small visual buttons',()=>{
 const p=stage().children.find(c=>c.name==='potionHelp').children.find(c=>c.name==='potionPopup');
 for(const name of ['use','discard'])for(const state of p.children.find(c=>c.name===name).children)
  assert(state.children.find(c=>c.name==='label').size[1]>=theme.layout.nativeText.lineHeight);
});
