import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {withViewport} from '../scripts/viewport-layout.mjs';
import {attachLowpolyScenes} from '../scripts/official-portraits.mjs';
import {nativeTheme as theme} from '../scripts/native-ui-theme.mjs';

// The bright row may extend outside the 1280-wide menu veil. Opaque trims
// cover only the exterior; changing global scaling/bleed cannot fix this seam.
test('menu scene trims cover exterior colour spill without covering the approved interior',()=>{
 const tree=withViewport(gameLayout(),theme);
 attachLowpolyScenes(tree,{menuBackground:true});
 const menu=tree.controls[1].children.find(c=>c.name==='menuPanel');
 const scene=menu.children.findIndex(c=>c.name==='lowpolyScene');
 const veil=menu.children.findIndex(c=>c.name==='lowpolyVeil');
 const edges=menu.children.filter(c=>c.name.startsWith('sceneEdge'));
 assert.equal(edges.length,2);
 for(const [i,edge] of edges.entries()){
  assert.equal(edge.kind,'image');assert.equal(edge.image,theme.image.rect);
  assert.equal(edge.colour,theme.color.backdrop);assert.equal(edge.opacity??1,1);
  assert.ok(menu.children.indexOf(edge)>scene&&menu.children.indexOf(edge)<veil);
  const [x]=edge.position,[w,h]=edge.size;
  assert.equal(h,720);
  if(i===0){assert.equal(x+w/2,-640);assert.ok(x-w/2<=-793.5);}
  else{assert.equal(x-w/2,640);assert.ok(x+w/2>=793.5);}
 }
 assert.deepEqual(tree.controls[0].size,[400,0]);
 assert.deepEqual(tree.controls[1].size,[1280,720]);
});

test('menu trims remain flag-local and the reported phone sliver maps entirely outside content',()=>{
 const make=()=>withViewport(gameLayout(),theme);
 const off=make();attachLowpolyScenes(off,{menuBackground:false});
 assert.doesNotMatch(JSON.stringify(off),/sceneEdge/);
 const before=make(),on=make();attachLowpolyScenes(on,{menuBackground:true});
 const panels=on.controls[1].children;
 for(const name of ['battlePanel','characterPanel']){
  const panel=panels.find(c=>c.name===name);
  assert.equal(panel.children.some(c=>c.name.startsWith('sceneEdge')),false);
 }
 const menu=panels.find(c=>c.name==='menuPanel');
 const original=before.controls[1].children.find(c=>c.name==='menuPanel');
 assert.deepEqual(menu.children.filter(c=>!c.name.startsWith('sceneEdge')&&c.name!=='lowpolyScene'),original.children);
 const scale=1179/720,offset=(2556-1280*scale)/2;
 assert.equal(offset,230);
 for(let pixel=225;pixel<=229;pixel++){
  const local=(pixel-offset)/scale-640;
  const left=menu.children.find(c=>c.name==='sceneEdgeLeft');
  assert.ok(local>=left.position[0]-left.size[0]/2&&local<left.position[0]+left.size[0]/2);
 }
});
