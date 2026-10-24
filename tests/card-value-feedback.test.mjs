import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {battleLayout,handPose,theme} from '../scripts/ui-layout.mjs';
const stage=battleLayout().controls.find(c=>c.name==='stage');
const cards=stage.children.filter(c=>/^card\d+$/.test(c.name));
const walk=(c,fn)=>{fn(c); for(const child of c.children??[])walk(child,fn);};
test('feedback retains approved card and description sizes, native line height and passive input',()=>{
  assert.equal(cards.length,10);
  for(const card of cards){
    assert.deepEqual(card.size,[148,208]);
    assert.deepEqual(card.children.find(c=>c.name==='label').size,[132,92]);
    const v=card.children.find(c=>c.name==='valueFeedback');
    assert.equal(v.visible,false);
    assert(card.children.indexOf(v)<card.children.findIndex(c=>c.name==='hit'),'card hit remains above feedback');
    assert.deepEqual(v.children.find(c=>c.name==='plate').colour,theme.color.panelRaised);
    walk(v,c=>{
      assert(!['cursorArea','presetButton','grid'].includes(c.kind));
      assert(!c.blockCursor&&!c.blockKeys&&!c.focusable);
      assert((c.children?.length??0)<=60);
      if(c.kind==='text'){
        assert(c.size[1]>=40); assert(c.text.fontSize>=14); assert(c.text.minFontSize>=14);
        assert(Math.abs(c.position[0])+c.size[0]/2<=v.size[0]/2);
        // Text boxes require 40 high natively; actual 14px glyph rows have 24px pitch.
        assert(Math.abs(c.position[1])+c.text.fontSize/2<=v.size[1]/2);
      }
    });
    assert(v.position[1]+v.size[1]/2<card.children.find(c=>c.name==='nameBand').position[1]-theme.layout.card.nameBand/2);
    assert(v.position[1]-v.size[1]/2>card.children.find(c=>c.name==='label').position[1]+46);
    for(const value of v.children.filter(c=>/^value\d+$/.test(c.name))){
      assert(value.position[0]+value.size[0]/2<=0,'numbers remain in exposed left half of a ten-card fan');
    }
  }
});
test('all base/upgrade card effects fit the feedback capacity and keep stable effect indices',()=>{
  const catalog=JSON.parse(readFileSync(new URL('../data/cards.json',import.meta.url)));
  for(const card of catalog.cards) for(const effects of [card.effects,card.upgrade?.effects].filter(Boolean)){
    assert(effects.filter(e=>['damage','damageAll','block'].includes(e.op)).length<=theme.layout.cardValueFeedback.rows,card.id);
  }
});
const linear=v=>{v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;};
const luminance=hex=>[0.2126,0.7152,0.0722].reduce((n,w,i)=>n+w*linear(parseInt(hex.slice(1+i*2,3+i*2),16)),0);
test('local colour contrast exceeds 4.5:1 on the actual feedback background',()=>{
 for(const key of ['cardValueIncrease','cardValueDecrease','text']){
   const a=luminance(theme.color[key]),b=luminance(theme.color.panelRaised);
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
