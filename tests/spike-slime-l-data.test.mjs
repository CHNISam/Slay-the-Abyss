import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const enemy=d=>d.enemies.enemies.find(e=>e.id==='spike_slime_l');
const policy={kind:'spike_slime_l',tackleIntent:'spike_slime_l_1',frailIntent:'spike_slime_l_2',rollRange:100,tackleCutoff:30};
const setup=()=>{const d=loadContent('data'),e=enemy(d);e.ai={...policy};e.hpRange={min:64,max:70};e.intents[0].effects=[{op:'damage',value:16},{op:'makeTempCardInDiscard',card:'slimed',value:2}];return d;};
test('existing playable Large Spike declares source-proven A0 HP policy and payload',()=>{const d=loadContent('data'),e=enemy(d);assert.deepEqual(e.hpRange,{min:64,max:70});assert.deepEqual(e.ai,policy);assert.deepEqual(e.intents[0].effects,[{op:'damage',value:16},{op:'makeTempCardInDiscard',card:'slimed',value:2}]);assert.deepEqual(e.intents[1].effects,[{op:'applyStatus',status:'frail',value:2}]);assert.deepEqual(validateContent(d),[]);});
test('bounded Large Spike policy is accepted',()=>assert.deepEqual(validateContent(setup()),[]));
for(const [field,value] of [['tackleIntent',undefined],['frailIntent',undefined],['tackleIntent','spike_slime_l_2'],['frailIntent','spike_slime_l_1'],['rollRange',0],['rollRange',65537],['rollRange',1.5],['tackleCutoff',-1],['tackleCutoff',100],['tackleCutoff',1.5],['guess',1]])test('Large Spike rejects malformed '+field+' '+value,()=>{const d=setup();enemy(d).ai[field]=value;if(value===undefined)delete enemy(d).ai[field];assert.ok(validateContent(d).some(e=>e.includes(field)));});
for(const [label,change] of [
 ['missing cards',p=>p.pop()],['only one Slimed',p=>p[1].value=1],['three Slimed',p=>p[1].value=3],['wrong card',p=>p[1].card='dazed'],['reversed payload',p=>p.reverse()],['missing attack',p=>p.shift()],['extra card creation',p=>p.push({...p[1]})],
])test('Large Spike rejects '+label,()=>{const d=setup();change(enemy(d).intents[0].effects);assert.ok(validateContent(d).some(e=>e.includes('tackleIntent')));});
test('shared validation does not let Medium Spike generate two Slimed',()=>{const d=setup(),m=d.enemies.enemies.find(e=>e.id==='spike_slime_m');m.intents[0].effects[1].value=2;assert.ok(validateContent(d).some(e=>e.includes('tackleIntent')));});
