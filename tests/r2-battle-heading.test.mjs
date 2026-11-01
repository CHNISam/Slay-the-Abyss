import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout} from '../scripts/ui-layout.mjs';
test('battle heading stays on the horizontal canvas center without touching HUD neighbours',()=>{
 const stage=battleLayout().controls.find(c=>c.name==='stage');
 const title=stage.children.find(c=>c.name==='title');
 assert.equal(title.text.align,'centre');
 assert.equal(title.size[0],360,'preserve the readable title width');
 for(const [w,h] of [[1280,720],[2048,1150],[2048,1171],[2048,1152]]){
  const k=Math.min(w/1280,h/720);
  assert.equal(w/2+title.position[0]*k,w/2,`${w}x${h}: heading is centered`);
  const left=title.position[0]-title.size[0]/2,right=title.position[0]+title.size[0]/2;
  for(const name of ['floorIcon','floor']){
   const neighbour=stage.children.find(c=>c.name===name);
   assert(neighbour.position[0]+neighbour.size[0]/2<=left,`${name} clears the centered heading`);
  }
  for(const name of ['player','piles','exhaust']){
   const neighbour=stage.children.find(c=>c.name===name);
   const l=neighbour.position[0]-neighbour.size[0]/2,r=neighbour.position[0]+neighbour.size[0]/2;
   assert(r<left||l>right,`${name} stays outside the heading at ${w}x${h}`);
  }
 }
});
