import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
const find=(c,name)=>c.name===name?c:(c.children??[]).map(v=>find(v,name)).find(Boolean);
const root=()=>({children:gameLayout().controls});

test('shared menu entry matches the canvas round copper button while keeping four full native hit states',()=>{
  const menu=find(find(root(),'exitEntry'),'open'),hit=find(menu,'hit');
  assert.deepEqual(menu.size,[48,48]);
  assert.deepEqual(hit.size,[48,48]);assert.equal(hit.focusable,true);
  for(const state of ['normal','hover','pressed','disabled']){
    const variant=find(hit,state),border=find(variant,'border'),plate=find(variant,'plate');
    assert.equal(border.image,theme.image.disc);assert.deepEqual(border.size,[36,36]);
    assert.equal(plate.image,theme.image.disc);assert.deepEqual(plate.size,[34,34]);
    const strokes=variant.children.filter(c=>/^menuStroke/.test(c.name));
    assert.equal(strokes.length,3,'the approved three-line menu glyph must not become text or an invented asset');
    assert.deepEqual(strokes.map(s=>s.position),[[0,4],[0,0],[0,-4]]);
    assert(strokes.every(s=>s.image===theme.image.rect&&s.size[0]===14&&s.size[1]===1));
    assert.equal(find(variant,'label').visible,false,'do not show the old rectangular menu label');
  }
  assert.equal(find(find(hit,'normal'),'plate').colour,'#241B19');
  assert.equal(find(find(hit,'normal'),'border').colour,'#6E5A42');
  assert.equal(find(find(hit,'normal'),'menuStroke1').colour,'#C9BDA4');
  assert.notDeepEqual(find(hit,'hover'),find(hit,'normal'));
  assert.deepEqual(find(hit,'pressed').scale,[.96,.96]);
});

test('map header and necessary return controls follow the canvas hierarchy rather than large boxed prose',()=>{
  const tree=root(),map=find(tree,'mapPanel');
  assert.equal(find(map,'title').text.fontSize,22);
  assert.equal(find(map,'title').text.colour,'#E9C77B');
  assert.equal(find(map,'headerDivider').image,theme.image.fadeLine);
  assert.equal(find(map,'headerDivider').size[1],1);
  for(const name of ['headerShade','titleLineLeft','titleLineRight'])assert(find(map,name));
  for(const action of [find(map,'previewBack'),find(tree,'combatRewards')]){
    assert.equal(action.position[1],-296);
    assert.equal(find(action,'plate').opacity,0,'base return plate stays transparent');
    for (const [name, rgb, alpha, inset] of [['panelHairline','#6E5A42',153/255,0],['panelShade','#070303',179/255,2]]) {
      const layer=find(action,name);
      assert.equal(layer.kind,'image');assert.equal(layer.image,theme.image.rect);
      assert.equal(layer.colour,rgb,'native importer RGB remains separate from opacity');
      assert.equal(layer.opacity,alpha);assert.deepEqual(layer.position,[0,0]);
      assert.deepEqual(layer.size,action.size.map(v=>v-inset));
      assert(action.children.indexOf(layer)<action.children.indexOf(find(action,'backIcon')),'shade stays behind the glyph and label');
    }
    assert.equal(find(action,'backIcon').image,theme.icon.back);
    assert.deepEqual(find(action,'hit').size,action.size);
    assert.equal(find(action,'hit').focusable,true);
    assert.equal(action.visible,false,'return is conditional, not a permanent map adornment');
  }
});
