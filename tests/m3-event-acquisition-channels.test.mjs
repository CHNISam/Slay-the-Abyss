import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateLaunchContent} from '../scripts/verify-launch-content.mjs';
const read=()=>JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
const transform='explicit_event:drug_dealer:transform';
const skullCard='explicit_event:knowing_skull:card';
const skullPotion='explicit_event:knowing_skull:potion';
const eventIds=['dead_adventurer','face_trader','colosseum','cursed_tome','drug_dealer','forgotten_altar','masked_bandits','vampires','designer','knowing_skull','nloth'];
const ids=(rows,channel)=>rows.filter(r=>r.channels.includes(channel)).map(r=>r.id).sort();
test('all eleven completed events retain exact current card and potion acquisition channels',()=>{
 const m=read();
 for(const id of eventIds){const rows=m.events.filter(r=>r.id===id);assert.equal(rows.length,1);assert.ok(rows[0].publicSourceMembership.length);}
 for(const choice of ['accept','give_vial'])assert.deepEqual(ids(m.sharedCards,`explicit_event:vampires:${choice}`),['bite']);
 assert.deepEqual(ids(m.sharedCards,'explicit_event:drug_dealer:jax'),['jax']);
 assert.deepEqual(ids(m.generatedCards,'explicit_event:forgotten_altar:smash'),['decay']);
 assert.deepEqual(ids(m.sharedCards,skullCard),m.sharedCards.filter(r=>r.rarity==='uncommon').map(r=>r.id).sort());
 assert.equal(ids(m.sharedCards,skullCard).length,20);
 assert.deepEqual(ids(m.potions,skullPotion),m.potions.map(r=>r.id).sort());assert.equal(m.potions.length,33);
 assert.deepEqual(ids(m.cards,transform),m.cards.filter(r=>r.rarity!=='basic').map(r=>r.id).sort());assert.equal(ids(m.cards,transform).length,72);
 assert.deepEqual(ids(m.sharedCards,transform),m.sharedCards.filter(r=>r.rarity!=='special').map(r=>r.id).sort());assert.equal(ids(m.sharedCards,transform).length,35);
 assert.deepEqual(ids(m.generatedCards,transform),['clumsy','decay','doubt','injury','normality','pain','parasite','regret','shame','writhe']);
 assert.deepEqual(validateLaunchContent(m,{runtime:false}),[]);
});
test('each added channel is required and impossible special or rarity substitutions fail closed',()=>{
 const routes=[['sharedCards','bite','explicit_event:vampires:accept'],['sharedCards','bite','explicit_event:vampires:give_vial'],
  ['sharedCards','jax','explicit_event:drug_dealer:jax'],['generatedCards','decay','explicit_event:forgotten_altar:smash'],
  ['sharedCards','bandage_up',skullCard],['potions','blood_potion',skullPotion],
  ['cards','anger',transform],['sharedCards','apotheosis',transform],['generatedCards','clumsy',transform]];
 for(const [category,id,channel]of routes){
  const m=read();m[category].find(r=>r.id===id).channels=m[category].find(r=>r.id===id).channels.filter(c=>c!==channel);
  assert.ok(validateLaunchContent(m,{runtime:false}).some(e=>e.includes(`${category}/${id} channels`)),`missing ${channel} must reject`);
 }
 for(const [category,id,channel]of [['sharedCards','apotheosis',skullCard],['sharedCards','bite',transform],['generatedCards','necronomicurse',transform],['cards','strike',transform]]){
  const m=read();m[category].find(r=>r.id===id).channels.push(channel);
  assert.ok(validateLaunchContent(m,{runtime:false}).some(e=>e.includes(`${category}/${id} channels`)),`impossible ${id}/${channel} must reject`);
 }
});
