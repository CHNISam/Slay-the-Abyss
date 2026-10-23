import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const enemy=d=>d.enemies.enemies.find(e=>e.id==='fungi_beast');
const policy={kind:'fungi_beast',biteIntent:'fungi_beast_1',growIntent:'fungi_beast_2',rollRange:100,biteCutoff:60,sporeCloudStacks:2};
const setup=()=>{const d=loadContent('data');enemy(d).ai={...policy};enemy(d).hpRange={min:22,max:28};return d;};
test('playable Fungi Beast uses sampled A0 HP and the attack/grow decision policy',()=>{const d=loadContent('data'),e=enemy(d);assert.deepEqual(e.ai,policy);assert.deepEqual(e.hpRange,{min:22,max:28});assert.deepEqual(e.intents.map(i=>i.effects),[[{op:'damage',value:6}],[{op:'gainStatus',status:'strength',value:3}]]);assert.deepEqual(validateContent(d),[]);});
test('bounded Fungi Beast policy is accepted',()=>assert.deepEqual(validateContent(setup()),[]));
for(const [field,value] of [['biteIntent',undefined],['growIntent',undefined],['biteIntent','missing'],['growIntent','missing'],['biteIntent','fungi_beast_2'],['growIntent','fungi_beast_1'],['rollRange',undefined],['rollRange',0],['rollRange',65537],['rollRange',1.5],['biteCutoff',undefined],['biteCutoff',-1],['biteCutoff',100],['biteCutoff',1.5],['guess',1]])test('Fungi policy rejects '+field+' '+value,()=>{const d=setup();enemy(d).ai[field]=value;if(value===undefined)delete enemy(d).ai[field];assert.ok(validateContent(d).some(e=>e.includes(field)));});
