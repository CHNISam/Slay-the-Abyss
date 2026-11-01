import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout} from '../scripts/ui-layout.mjs';
test('pile badges attach small circles to icons while retaining original touch areas',()=>{
 const controls=battleLayout().controls.find(c=>c.name==='stage').children;
 const child=n=>controls.find(c=>c.name===n);
 for(const [name,side] of [['draw',1],['discard',-1]]){
  const icon=child(name+'Icon'),ring=child(name+'BadgeRing'),value=child(name);
  assert.equal(ring.size[0],ring.size[1],'badge must be circular');
  assert.ok(ring.size[0]<=36,'badge must be small');
  const dx=Math.abs(ring.position[0]-icon.position[0]),dy=Math.abs(ring.position[1]-icon.position[1]);
  assert.ok(Math.hypot(dx,dy)<icon.size[0]/2+ring.size[0]/2,'badge must meet icon rim');
  const hit=icon.children.find(c=>c.name==='hit');
  assert.deepEqual(hit.size,[84,82]);assert.deepEqual(hit.position,[side*10,1]);
  assert.ok(value.text.fontSize*0.6*3+4<=value.size[0],'three-digit count fits with native text inset and no smaller font');
  assert.equal(value.text.fontSize,20);assert.equal(value.text.minFontSize,20);
  assert.deepEqual(child(name+'Badge').size,[34,34],'thin rim leaves contrast backing for three-digit ink');
 }
});

test('real Host count labels preserve 0/1/9/10 and three-digit pile values',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const r=runLua('tests/lua/hud_r2_pile_counts.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/HUD_R2_COUNTS_PASS/);
});
