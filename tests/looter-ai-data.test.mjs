import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const get=d=>d.enemies.enemies.find(e=>e.id==='looter');
test('Looter A0 source values and narrow escape intent validate',()=>{const d=loadContent('data'),e=get(d);assert.deepEqual(e.hpRange,{min:44,max:48});assert.equal(e.ai.stealAmount,15);assert.equal(e.ai.talkChance,Math.fround(.6));assert.deepEqual(e.intents.map(x=>[x.kind,x.effects[0]?.value]),[['attack',10],['attack',12],['defend',6],['escape',undefined]]);assert.deepEqual(validateContent(d),[]);});
for(const [key,value] of [['mugIntent','missing'],['lungeIntent','looter_2'],['escapeIntent','looter_1'],['stealAmount',-1],['rollRange',0],['talkChance',.6],['smokeChance',.6],['guess',1]])test('Looter rejects '+key,()=>{const d=loadContent('data');get(d).ai[key]=value;assert.ok(validateContent(d).some(x=>x.includes(key)));});
test('escape cannot be used without the narrow matching Looter policy',()=>{const d=loadContent('data');delete get(d).ai;assert.ok(validateContent(d).some(x=>x.includes('escape')));});
test('attack empty effects remain invalid',()=>{const d=loadContent('data');get(d).intents[0].effects=[];assert.ok(validateContent(d).some(x=>x.includes('effects')));});
test('Looter effect field order does not affect schema',()=>{const d=loadContent('data');get(d).intents[0].effects=[{value:10,op:'damage'}];assert.deepEqual(validateContent(d),[]);});
