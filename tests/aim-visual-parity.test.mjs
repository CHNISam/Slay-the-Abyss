import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout,theme} from '../scripts/ui-layout.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('native aim keeps fourteen pooled controls and ring (drawn as the STS star chain)',()=>{
 const layer=battleLayout().controls.find(c=>c.name==='stage').children.find(c=>c.name==='dragLayer');
 assert.equal(theme.layout.cardDrag.aimPresentation,undefined);
 assert.equal(layer.children.filter(c=>/^aim\d+$/.test(c.name)||c.name==='reticle').length,15);
 assert(!layer.children.some(c=>c.name.startsWith('aimGlow')));
 for(let i=1;i<=14;i++){
  const dot=layer.children.find(c=>c.name==='aim'+i);
  assert.equal(dot.kind,'image');assert.equal(dot.image,theme.image.diamond);
  assert.equal(dot.children,undefined);
 }
 const reticle=layer.children.find(c=>c.name==='reticle');
 assert.equal(reticle.kind,'image');assert.equal(reticle.image,theme.image.ring);
});
test('real card aiming draws the STS star-chain TargetArrow while touch cancellation remains intact',()=>{
 const result=runLua('tests/lua/aim_visual_parity.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/AIM_VISUAL_PARITY_PASS 3/);
});
