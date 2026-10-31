import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { potionSlotVisual } from '../scripts/potion-slot-visual.mjs';
const named=(a,n)=>a.find(c=>c.name===n);
const controls=()=>potionSlotVisual(theme,{border:{name:'border',kind:'image',position:[0,0],size:[34.667,34.667],colour:'#FFFF00'},
 plate:{name:'plate',kind:'image',position:[0,0],size:[30.667,30.667],colour:'#FF0000'},bottleSize:16,ink:'#FFFFFF'});

test('actual empty shell renders a half-alpha face and separated tangent dashes, never the old solid face',()=>{
 const tree=controls(),empty=named(tree,'emptyShell');assert.ok(empty,'empty needs its own rendered shell');
 assert.equal(named(tree,'border').visible,false);assert.equal(named(tree,'plate').visible,false);
 const face=named(empty.children,'face');assert.equal(face.colour,'#1A1312');assert.equal(face.opacity,128/255);
 const dashes=named(empty.children,'dashes').children;assert.equal(dashes.length,18);
 for(const [i,d]of dashes.entries()){
  assert.equal(d.image,theme.image.rect);assert.equal(d.colour,'#6E5A42');assert.equal(d.size[1],1);
  assert.ok(d.size[0]>2.8&&d.size[0]<3);assert.ok(Math.abs(Math.hypot(...d.position)-16.8335)<.001);
  assert.equal(d.rotation,-i*20);assert.ok(d.size[0]<Math.PI*33.667/18,'a real gap exists in the rendered border');
 }
 assert.equal(empty.children.some(c=>c.name==='rim'||c.name==='border'),false);
});

test('actual filled shells preserve source-specific border, radial light and empty/selected separation',()=>{
 const tree=controls();
 for(const [name,rim,light,base,mid]of [['filledShell','#C9A86E','#3A2E28','#2C231E','#312722'],['fireShell','#C8705A','#4A2C24','#33221D','#3B251F']]){
  const shell=named(tree,name);assert.ok(shell);assert.equal(shell.visible,false);
  assert.equal(named(shell.children,'rim').colour,rim);
  assert.equal(named(shell.children,'base').colour,base,'base is a fitted interpolation of source endpoints');
  const glow=named(shell.children,'light');assert.equal(glow.image,theme.image.discSoft);assert.equal(glow.colour,mid);
  assert.deepEqual(glow.position,[0,0]);assert.ok(Math.abs(glow.size[0]-32.667)<.001,'broad light covers the whole inner face');
  const focus=named(shell.children,'focusLight');assert.equal(focus.image,theme.image.discSoft);assert.equal(focus.colour,light);
  assert.ok(Math.abs(focus.position[1]-4.22772534)<.001,'source-field fit; not a claim of exact CSS focal pixels');
  assert.ok(Math.abs(focus.size[0]-24.21154932)<.001);
  assert.ok(Math.hypot(...focus.position)+focus.size[0]/2<=glow.size[0]/2+.001,'bounded soft light never assumes clipping');
 }
 const selected=named(tree,'selectedShell');assert.equal(selected.visible,false);
 assert.equal(named(selected.children,'glow').image,theme.image.glow);
 assert.equal(named(selected.children,'glow').opacity,102/255);
 assert.equal(named(selected.children,'spread').opacity,51/255);
 assert.ok(Math.abs(named(selected.children,'spread').size[0]-40)<.001);
 assert.equal(named(tree,'bottle').image,theme.icon.potion.fire_potion,'official bottle IDs stay untouched');
});
