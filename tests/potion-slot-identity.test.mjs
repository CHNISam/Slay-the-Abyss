import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout,theme} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('centered readable bottles retain separate full-height captions below five safe touch slots',()=>{
 const layout=battleLayout(),stage=layout.controls.find(c=>c.name==='stage');
 const group=stage.children.find(c=>c.name==='potionHelp');
 const slots=[...stage.children,...group.children].filter(c=>/^potion\d$/.test(c.name));
 assert.equal(slots.length,5);assertNativeUiCapacity(layout);
 for(const slot of slots)for(const state of slot.children){
  const text=group.children.find(c=>c.name==='potionCaption'+slot.name.slice(6)),bottle=state.children.find(c=>c.name==='bottle');
  assert(text,'caption has a full-canvas parent, not a clipping button');
  assert.deepEqual(group.size,theme.canvas.base);
  const localY=text.position[1]-slot.position[1];
  assert.equal(text.text.fontSize,20);assert.equal(text.text.minFontSize,20);assert.equal(text.size[1],theme.layout.nativeText.lineHeight);
  assert.deepEqual(bottle.position,[0,0],'bottle must not be pushed aside for its caption');
  assert.deepEqual(bottle.size,[32,32],'bottle uses readable inset within 44px shell');
  assert.equal(bottle.rotation??0,0,'do not guess a correction for unverified atlas tilt');
  assert.deepEqual(slot.size,[44,44],'touch target unchanged');
  assert.equal(text.position[0],slot.position[0],'identity caption aligns with its bottle');
  assert(localY+text.size[1]/2<=-slot.size[1]/2-2,'caption clears the shell');
  assert.equal(text.kind,'text');assert.equal(text.focusable??false,false);
  const popup=group.children.find(c=>c.name==='potionPopup');
  assert(popup.position[1]+popup.size[1]/2<=text.position[1]-text.size[1]/2-2,'popup clears caption row');
  assert(text.size[0]<=slot.size[0],'caption exceeds physical slot width');
  for(let axis=0;axis<2;axis++)assert(Math.abs(text.position[axis])+text.size[axis]/2<=theme.canvas.base[axis]/2,'caption outside viewport');
  assert.equal(state.children.length,8,'reuse label without adding native children');
 }
});
test('all available potion identities have stable distinct readable captions and preserve explicit-use ownership',()=>{
 const r=runLua('tests/lua/potion_slot_identity.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/POTION_SLOT_IDENTITY_PASS/);
});
