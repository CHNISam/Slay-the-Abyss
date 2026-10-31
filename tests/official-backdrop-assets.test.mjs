import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
test('solid title and readable official selection/battle pictures retain their approved bindings',()=>{
 const ids=nativeTheme.image.officialBackdrops;
 assert.deepEqual(ids,{title:107271,selection:107050,act1_1:107106,act1_2:107107,act1_3:107110,
  act2_1:107108,act2_2:107109,act2_3:107105,boss1:107280,boss2:107279});
 assert.equal(new Set(Object.values(ids)).size,10);
 const layout=gameLayout();assertNativeUiCapacity(layout);
 const menu=layout.controls.find(c=>c.name==='menuPanel');
 const selection=layout.controls.find(c=>c.name==='characterPanel');
 const backdrop=menu.children.find(c=>c.name==='backdrop');
 assert.equal(backdrop.image,nativeTheme.image.rect,'approved title uses a solid primitive');
 assert.equal(backdrop.colour,nativeTheme.color.backdrop);
 assert.deepEqual(backdrop.size,nativeTheme.canvas.base);
 assert(!menu.children.some(c=>c.image===ids.title),'retired official title picture must not return');
 for(const [name,opacity]of [['lowpolyVeil',0.28],['titleBand',0.55]]){
  const layer=menu.children.find(c=>c.name===name);
  assert.equal(layer.image,nativeTheme.image.rect);assert.equal(layer.colour,nativeTheme.color.backdrop);
  assert.equal(layer.opacity,opacity);
  assert.deepEqual(layer.position,name==='lowpolyVeil'?[0,0]:[0,150]);
  assert.deepEqual(layer.size,name==='lowpolyVeil'?nativeTheme.canvas.base:[1280,230]);
  assert(menu.children.indexOf(layer)>menu.children.indexOf(backdrop));
  assert(menu.children.indexOf(layer)<menu.children.findIndex(c=>c.name==='title'),'readability layer stays behind title');
 }
 assert.equal(selection.children.find(c=>c.name==='veil').image,ids.selection);
 const battle=layout.controls.find(c=>c.name==='officialBattleBackdrop');
 assert.equal(battle.children.filter(c=>c.name!=='readabilityVeil').length,8);
 for(const c of battle.children.filter(c=>c.name!=='readabilityVeil'))assert.equal(c.image,ids[c.name]);
 for(const [panel,name]of [[selection,'officialBackdropVeil'],[battle,'readabilityVeil']]){
  const veil=panel.children.find(c=>c.name===name);
  assert.equal(veil.image,nativeTheme.image.rect);assert.equal(veil.colour,nativeTheme.color.officialBackdropVeil.slice(0,7));
  assert.equal(veil.opacity,128/255);assert.deepEqual(veil.size,nativeTheme.canvas.base);
 }
 assert(!JSON.stringify(layout).includes('officialVista_'));
});
