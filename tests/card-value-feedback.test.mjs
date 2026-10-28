import test from 'node:test';
import assert from 'node:assert/strict';
import {battleLayout,handPose,theme} from '../scripts/ui-layout.mjs';
import {nativeInlinePreview} from '../scripts/native-inline-preview.mjs';
const stage=battleLayout().controls.find(c=>c.name==='stage');
const cards=stage.children.filter(c=>/^card\d+$/.test(c.name));
test('offline preview preserves sentence flow and maps only native colour spans',()=>{
  assert.equal(nativeInlinePreview('获得 <color=#EF7672>3↓</color> 点格挡。'),'获得 <span style="color:#EF7672">3↓</span> 点格挡。');
  assert.equal(nativeInlinePreview('<script> & x'),'&lt;script> &amp; x');
});
test('value feedback stays inside the original description and never replaces card art with badges',()=>{
  assert.equal(cards.length,10);
  for(const card of cards){
    assert.deepEqual(card.size,[148,208]);
    assert.deepEqual(card.children.find(c=>c.name==='label').size,[132,92]);
    assert.deepEqual(card.children.map(c=>c.name),['glow','shadow','border','plate','roundShadow','roundFrame','roundBody','nameBand','nameRule','artPlate','artWell','skin','name','art',
      'typeEdge','typeTag','tagEdge','tagBody','type','label','roleRing','roleMark','costHalo','costCore','costDisc','cost','costDirection','blockedReason','hit']);
    assert.notEqual(card.children.find(c=>c.name==='art').visible,false);
    assert(card.children.find(c=>c.name==='label').text.minFontSize>=14);
  }
});
const linear=v=>{v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;};
const luminance=hex=>[0.2126,0.7152,0.0722].reduce((n,w,i)=>n+w*linear(parseInt(hex.slice(1+i*2,3+i*2),16)),0);
test('local colour contrast exceeds 4.5:1 on the description backgrounds',()=>{
 for(const background of ['panel','cardBody']) for(const key of ['cardValueIncrease','cardValueDecrease','text']){
   const a=luminance(theme.color[key]),b=luminance(theme.color[background]);
   const ratio=(Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
   assert(ratio>=4.5,`${key}: ${ratio}`);
   console.log(`${key}: ${ratio.toFixed(3)}:1`);
 }
});
test('1/5/10 cards preserve their full feedback bounds on phone, PC and 19.5:9 stage',()=>{
 for(const [width,height] of [[1280,720],[1600,900],[1560,720]]) for(const count of [1,5,10]){
   const k=Math.min(width/1280,height/720);
   for(let i=0;i<count;i++)for(const selected of [false,true]){
     const pose=handPose(count,i,selected),angle=Math.abs(pose.rotation)*Math.PI/180;
     const [w,h]=cards[0].size,scale=pose.scale[0];
     const halfW=(w*Math.cos(angle)+h*Math.sin(angle))*scale/2;
     const halfH=(h*Math.cos(angle)+w*Math.sin(angle))*scale/2;
     assert((Math.abs(pose.position[0])+halfW)*k<=width/2-theme.canvas.safe.x*k);
     assert((pose.position[1]-halfH)*k>=-height/2+theme.canvas.safe.y*k);
   }
 }
});
