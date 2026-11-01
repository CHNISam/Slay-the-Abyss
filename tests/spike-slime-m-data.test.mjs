import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const enemy=d=>d.enemies.enemies.find(e=>e.id==='spike_slime_m');
const slimed=d=>d.cards.cards.find(c=>c.id==='slimed');
const policy={kind:'spike_slime_m',tackleIntent:'spike_slime_m_1',frailIntent:'spike_slime_m_2',rollRange:100,tackleCutoff:30};
const setup=()=>{const d=loadContent('data'),e=enemy(d);e.ai={...policy};e.hpRange={min:28,max:32};e.intents[0].effects=[{op:'damage',value:8},{op:'makeTempCardInDiscard',card:'slimed',value:1}];if(!slimed(d))d.cards.cards.push({id:'slimed',name:'Slimed',type:'status',rarity:'common',cost:1,effects:[],exhaust:true,text:'花费 1 点能量清除本牌。',sts_name:'Slimed'});return d;};
test('playable Spike M carries its actual A0 attack and status card contract',()=>{const d=loadContent('data'),e=enemy(d);assert.deepEqual(e.ai,policy);assert.deepEqual(e.hpRange,{min:28,max:32});assert.deepEqual(e.intents[0].effects,[{op:'damage',value:8},{op:'makeTempCardInDiscard',card:'slimed',value:1}]);assert.ok(slimed(d));assert.deepEqual(validateContent(d),[]);});
test('bounded Spike policy and playable empty-use status are accepted',()=>assert.deepEqual(validateContent(setup()),[]));
for(const [field,value] of [['tackleIntent',undefined],['frailIntent',undefined],['tackleIntent','spike_slime_m_2'],['frailIntent','spike_slime_m_1'],['rollRange',0],['rollRange',65537],['rollRange',1.5],['tackleCutoff',-1],['tackleCutoff',100],['tackleCutoff',1.5],['guess',1]])test('AI rejects malformed '+field+' '+value,()=>{const d=setup();enemy(d).ai[field]=value;if(value===undefined)delete enemy(d).ai[field];assert.ok(validateContent(d).some(e=>e.includes(field)));});
test('Tackle cannot omit its queued Slimed payload',()=>{const d=setup();enemy(d).intents[0].effects.pop();assert.ok(validateContent(d).some(e=>e.includes('tackleIntent')));});
for(const [label,change] of [
 ['reversed card before damage',effects=>effects.reverse()],
 ['missing attack',effects=>effects.shift()],
 ['extra queued card',effects=>effects.push({...effects[1]})],
])test('Tackle rejects '+label,()=>{const d=setup();change(enemy(d).intents[0].effects);assert.ok(validateContent(d).some(e=>e.includes('tackleIntent')));});
test('ordinary empty-effect cards are still rejected',()=>{for(const type of ['attack','skill','power','curse']){const d=setup();const c=slimed(d);c.id='other_empty';c.type=type;enemy(d).intents[0].effects[1].card=c.id;assert.ok(validateContent(d).some(e=>e.includes('.effects')));}});
for(const [field,value] of [['cost',0],['cost',2],['exhaust',false],['ethereal',true],['upgrade',{cost:0}],['effects',[{op:'block',value:1}]],['condition','only_attacks_in_hand'],['costMode','all_energy']])test('Slimed rejects unsupported '+field+' '+JSON.stringify(value),()=>{const d=setup();slimed(d)[field]=value;assert.ok(validateContent(d).some(e=>e.includes('.'+field)));});
test('unrecognized empty-use statuses are not opened by Slimed',()=>{const d=setup();slimed(d).id='unknown_empty';enemy(d).intents[0].effects[1].card='unknown_empty';assert.ok(validateContent(d).some(e=>e.includes('.effects')));});
