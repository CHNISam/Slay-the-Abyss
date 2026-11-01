import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout,theme} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('existing potion captions and bottles have separate native rectangles within five safe slots',()=>{
 const layout=battleLayout(),stage=layout.controls.find(c=>c.name==='stage');
 const group=stage.children.find(c=>c.name==='potionHelp');
 const slots=[...stage.children,...group.children].filter(c=>/^potion\d$/.test(c.name));
 assert.equal(slots.length,5);assertNativeUiCapacity(layout);
 for(const slot of slots)for(const state of slot.children){
  const text=state.children.find(c=>c.name==='label'),bottle=state.children.find(c=>c.name==='bottle');
  assert.equal(text.text.fontSize,20);assert.equal(text.text.minFontSize,20);assert.equal(text.size[1],theme.layout.nativeText.lineHeight);
  assert(bottle.position[0]+bottle.size[0]/2<=text.position[0]-text.size[0]/2,'bottle and caption overlap');
  assert(Math.abs(text.position[0])+text.size[0]/2<=slot.size[0]/2,'caption exceeds physical slot width');
  for(let axis=0;axis<2;axis++)assert(Math.abs(slot.position[axis]+text.position[axis])+text.size[axis]/2<=theme.canvas.base[axis]/2,'caption outside viewport');
  assert.equal(state.children.length,8,'reuse label without adding native children');
 }
});
test('all available potion identities have stable distinct readable captions and preserve explicit-use ownership',()=>{
 const r=runLua('tests/lua/potion_slot_identity.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/POTION_SLOT_IDENTITY_PASS/);
});
