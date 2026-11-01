import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const wizard = d => d.enemies.enemies.find(e => e.id === 'wizard_gremlin');
test('Wizard A0 values and empty charge are accepted', () => {
 const d=loadContent('data'), e=wizard(d);
 assert.deepEqual(e.hpRange,{min:21,max:25});
 assert.deepEqual(e.ai,{kind:'charge_then_attack',initialCharge:1,chargeLimit:3,chargeIntent:'wizard_gremlin_1',attackIntent:'wizard_gremlin_3',rollRange:100});
 assert.deepEqual(e.intents,[{id:'wizard_gremlin_1',kind:'charge',effects:[]},{id:'wizard_gremlin_3',kind:'attack',effects:[{op:'damage',value:25}]}]);
 assert.deepEqual(validateContent(d),[]);
});
for (const [name, mutate, field] of [
 ['unknown AI field',e=>e.ai.extra=1,'extra'],
 ['missing opening roll range',e=>delete e.ai.rollRange,'rollRange'],
 ['zero opening roll range',e=>e.ai.rollRange=0,'rollRange'],
 ['negative opening roll range',e=>e.ai.rollRange=-1,'rollRange'],
 ['fractional opening roll range',e=>e.ai.rollRange=99.5,'rollRange'],
 ['oversized opening roll range',e=>e.ai.rollRange=65537,'rollRange'],
 ['string opening roll range',e=>e.ai.rollRange='100','rollRange'],
 ['missing initial charge',e=>delete e.ai.initialCharge,'initialCharge'],
 ['negative initial charge',e=>e.ai.initialCharge=-1,'initialCharge'],
 ['fractional initial charge',e=>e.ai.initialCharge=0.5,'initialCharge'],
 ['already charged initial state',e=>e.ai.initialCharge=3,'initialCharge'],
 ['missing charge limit',e=>delete e.ai.chargeLimit,'chargeLimit'],
 ['zero charge limit',e=>e.ai.chargeLimit=0,'chargeLimit'],
 ['fractional charge limit',e=>e.ai.chargeLimit=3.5,'chargeLimit'],
 ['oversized charge limit',e=>e.ai.chargeLimit=2147483648,'chargeLimit'],
 ['missing charge intent',e=>delete e.ai.chargeIntent,'chargeIntent'],
 ['missing attack intent',e=>delete e.ai.attackIntent,'attackIntent'],
 ['unknown charge intent',e=>e.ai.chargeIntent='missing','chargeIntent'],
 ['charge points to attack',e=>e.ai.chargeIntent='wizard_gremlin_3','chargeIntent'],
 ['attack points to charge',e=>e.ai.attackIntent='wizard_gremlin_1','attackIntent'],
 ['buff masquerades as charge',e=>e.intents[0].kind='buff','chargeIntent'],
 ['charge has block',e=>e.intents[0].effects=[{op:'block',value:3}],'effects'],
 ['charge has nonarray effects',e=>e.intents[0].effects={},'effects'],
 ['charge has no effects field',e=>delete e.intents[0].effects,'effects'],
 ['orphan charge',e=>delete e.ai,'kind'],
 ['empty attack',e=>e.intents[1].effects=[],'effects'],
 ['nonarray intents',e=>e.intents={},'intents'],
]) test(`Wizard schema rejects ${name}`,()=>{
 const d=loadContent('data'); mutate(wizard(d)); assert.ok(validateContent(d).some(e=>e.includes(field)));
});
test('empty cards remain invalid',()=>{
 const d=loadContent('data'); d.cards.cards[0].effects=[];
 assert.ok(validateContent(d).some(e=>e.includes('effects')));
});
