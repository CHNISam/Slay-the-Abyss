import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const enemy=d=>d.enemies.enemies.find(e=>e.id==='shield_gremlin');
const policy={kind:'shield_gremlin',protectIntent:'shield_gremlin_1',attackIntent:'shield_gremlin_2',rollRange:100};
const setup=()=>{const d=loadContent('data'),e=enemy(d);e.ai={...policy};e.intents[0].effects=[{op:'block',value:7,target:'random_ally'}];return d;};
test('playable Shield Gremlin uses A0 HP12-15 and random ally Protect7 / Bash6',()=>{
 const d=loadContent('data'),e=enemy(d);assert.deepEqual(e.hpRange,{min:12,max:15});assert.deepEqual(e.ai,policy);
 assert.deepEqual(e.intents,[{id:'shield_gremlin_1',kind:'defend',effects:[{op:'block',value:7,target:'random_ally'}]},{id:'shield_gremlin_2',kind:'attack',effects:[{op:'damage',value:6}]}]);assert.deepEqual(validateContent(d),[]);
});
test('the new bounded policy and enemy block target are accepted',()=>assert.deepEqual(validateContent(setup()),[]));
for(const [label,key,value] of [['missing Protect','protectIntent',undefined],['missing attack','attackIntent',undefined],['wrong Protect','protectIntent','shield_gremlin_2'],['wrong attack','attackIntent','shield_gremlin_1'],['missing roll','rollRange',undefined],['zero roll','rollRange',0],['fractional roll','rollRange',1.5],['oversized roll','rollRange',65537],['unknown field','guess',1]])test('Shield rejects '+label,()=>{
 const d=setup();enemy(d).ai[key]=value;if(value===undefined)delete enemy(d).ai[key];assert.ok(validateContent(d).some(e=>e.includes(key)));
});
test('Protect cannot silently regress to a self Block payload',()=>{
 const d=setup();delete enemy(d).intents[0].effects[0].target;assert.ok(validateContent(d).some(e=>e.includes('protectIntent')));
});
test('only random_ally is a valid enemy block target selector',()=>{
 const d=setup();enemy(d).intents[0].effects[0].target='all_allies';assert.ok(validateContent(d).some(e=>e.includes('.target')));
});
test('random ally block is not a player card effect',()=>{
 const d=setup();d.cards.cards.find(c=>c.id==='defend').effects[0].target='random_ally';assert.ok(validateContent(d).some(e=>e.startsWith('cards[')&&e.includes('.target')));
});
test('random ally block is not a relic or potion effect',()=>{
 for(const type of ['relics','potions']){const d=setup();const e=d[type][type].find(e=>e.effects?.some(x=>x.op==='block'));assert.ok(e);e.effects.find(x=>x.op==='block').target='random_ally';assert.ok(validateContent(d).some(x=>x.startsWith(type+'[')&&x.includes('.target')));}
});
