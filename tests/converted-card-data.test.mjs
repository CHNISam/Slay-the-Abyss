import test from 'node:test';import assert from 'node:assert/strict';
import{validateConvertedCardPack}from'../scripts/art/converted-card-data.mjs';
const fixture=()=>({schemaVersion:1,canvas:[144,64],encoding:'xywh-rgb24-hex14',cards:{strike:{rectangleCount:1,rectangles:'00009040010203',sourcePreviewPath:'art/cards/traveler-geo/strike/preview-contain-144x64.png',sourcePreviewSha256:'a'.repeat(64),std:3,mae:0,maxError:0}}});
test('compact data keeps exact full canvas coverage and card identity',()=>{
 assert.equal(validateConvertedCardPack(fixture(),['strike']).cards.strike.rectangleCount,1);
 for(const mutate of [p=>p.cards.strike.rectangleCount=0,p=>p.cards.strike.rectangles='00000040010203',p=>p.cards.strike.rectangles='00008f40010203',p=>p.cards.strike.rectangles='01009040010203',p=>p.cards.strike.sourcePreviewPath='../../outside.png',p=>p.cards.strike.std=11,p=>p.cards.strike.rectangles='x'.repeat(14),p=>p.cards.bad=p.cards.strike]){
  const p=fixture();mutate(p);assert.throws(()=>validateConvertedCardPack(p,['strike']));
 }
 const overlap=fixture();overlap.cards.strike.rectangleCount=2;overlap.cards.strike.rectangles='00009040010203'.repeat(2);assert.throws(()=>validateConvertedCardPack(overlap,['strike']),/overlap/);
});
