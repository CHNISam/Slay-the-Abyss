import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
const named=(list,name)=>list.find(c=>c.name===name);
function descendant(control,name){
  if(control.name===name)return control;
  for(const c of control.children??[]){const found=descendant(c,name);if(found)return found;}
}
test('three-slot discard modal uses approved button states and blocks the underlying page',()=>{
  const controls=gameLayout().controls;
  const entry=named(controls,'potionEntry'),panel=named(controls,'potionPanel');
  assert.ok(entry,'shared potion counter must open the discard menu');
  assert.ok(panel,'discard requires an explicit selection and confirmation');
  assert.equal(entry.visible,false);assert.equal(panel.visible,false);
  assert.equal(named(panel.children,'blocker').kind,'cursorArea');
  for(const name of ['slot1','slot2','slot3','cancel','discard']){
    const hit=named(named(panel.children,name).children,'hit');
    assert.equal(hit.kind,'presetButton');
    for(const state of ['normal','hover','pressed','disabled'])assert.ok(named(hit.children,state));
  }
  for(const c of panel.children.filter(c=>['slot1','slot2','slot3','cancel','discard'].includes(c.name))){
    assert.ok(Math.abs(c.position[0])+c.size[0]/2<=theme.canvas.base[0]/2-theme.canvas.safe.x);
    assert.ok(Math.abs(c.position[1])+c.size[1]/2<=theme.canvas.base[1]/2-theme.canvas.safe.y);
  }
});
test('shared potion counter clears core top-bar data and existing utility controls',()=>{
  const controls=gameLayout().controls;
  const entry=named(named(controls,'potionEntry').children,'open');
  const obstacles=[descendant(named(controls,'mapPanel'),'title'),
    descendant(named(controls,'battlePanel'),'title'),descendant(named(controls,'battlePanel'),'player'),
    descendant(named(controls,'deckEntry'),'open'),descendant(named(controls,'exitEntry'),'open'),
    ...['title','hp','gold','relics'].map(name=>descendant(named(controls,'nodePanel'),name))];
  for(const c of obstacles){
    const overlaps=entry.position.every((p,i)=>Math.abs(p-c.position[i])<(entry.size[i]+c.size[i])/2);
    assert.equal(overlaps,false,`potion entry overlaps ${c.name}`);
  }
});
