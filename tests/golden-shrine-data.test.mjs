import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const bundle=()=>loadContent('data');
const regret=d=>d.cards.cards.find(c=>c.id==='regret');
const definition={id:'regret',name:'余悔',sts_name:'Regret',type:'curse',rarity:'curse',cost:-2,effects:[]};
const setup=()=>{const d=bundle();if(!regret(d))d.cards.cards.push({...definition});return d;};
test('shipped Golden Shrine is A0 complete and Regret retains exact curse ABI',()=>{
 const d=bundle();assert.deepEqual(d.rules.events.golden_shrine,{gold:100,curseGold:275,curse:'regret'});
 assert.equal(d.rules.events.poolMode,'restricted-seven');assert.ok(regret(d));
 for(const key of ['id','type','rarity','cost'])assert.equal(regret(d)[key],definition[key]);
 assert.deepEqual(regret(d).effects,[]);assert.equal(regret(d).upgrade,undefined);assert.deepEqual(validateContent(d),[]);
});
test('narrow Regret ABI accepts only the supported curse and no fake empty ordinary use',()=>{assert.deepEqual(validateContent(setup()),[]);});
for(const [field,value] of [['id','other_curse'],['type','skill'],['rarity','common'],['cost',0],['cost',-1],['effects',[{op:'block',value:1}]],['upgrade',{cost:0}],['ethereal',true],['exhaust',true],['costMode','all_energy'],['condition','only_attacks_in_hand']])
 test(`Regret rejects unsupported ${field} ${JSON.stringify(value)}`,()=>{const d=setup();regret(d)[field]=value;assert.ok(validateContent(d).length);});
test('Golden Shrine canonical numbers and curse are guarded by validation',()=>{
 for(const [key,value]of [['gold',99],['curseGold',274],['curse','dazed']]){const d=setup();d.rules.events.poolMode='restricted-seven';d.rules.events.golden_shrine={gold:100,curseGold:275,curse:'regret',[key]:value};assert.ok(validateContent(d).some(e=>e.includes('golden_shrine.'+key)));}
});
test('original and curse card presentation have separate canonical identities',()=>{
 const p=JSON.parse(readFileSync('data/presentation/traveler.zh-CN.json','utf8')).cards.regret;
 assert.ok(p);assert.equal(p.name,'余悔');assert.match(p.textTemplate,/无法打出/);assert.match(p.textTemplate,/手牌/);assert.doesNotMatch(p.name,/Regret/);
});
