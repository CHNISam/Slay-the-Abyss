import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateContent, contentFiles} from '../scripts/validate-data.mjs';
const bundle=()=>Object.fromEntries(contentFiles.map(id=>[id,JSON.parse(readFileSync(`data/${id}.json`,'utf8'))]));
test('Dazed exact status sentinel and Sentry generation payload validate',()=>{
 const d=bundle();const card=d.cards.cards.find(c=>c.id==='dazed');assert.ok(card);
 assert.equal(card.cost,-2);assert.equal(card.type,'status');assert.equal(card.rarity,'common');
 assert.equal(card.ethereal,true);assert.deepEqual(card.effects,[]);assert.equal(card.upgrade,undefined);
 d.enemies.enemies[0].intents[0].effects=[{op:'makeTempCardInDiscard',card:'dazed',value:2}];
 assert.deepEqual(validateContent(d),[]);
});
for(const [label,mutate] of [
 ['ordinary empty use',d=>d.cards.cards[0].effects=[]],
 ['ordinary negative cost',d=>d.cards.cards[0].cost=-2],
 ['status -1 unsupported cost',d=>d.cards.cards.find(c=>c.id==='dazed').cost=-1],
 ['status sentinel with effects',d=>d.cards.cards.find(c=>c.id==='dazed').effects=[{op:'block',value:1}]],
 ['status sentinel costMode',d=>d.cards.cards.find(c=>c.id==='dazed').costMode='all_energy'],
 ['status sentinel upgrade',d=>d.cards.cards.find(c=>c.id==='dazed').upgrade={cost:0}],
 ...[-1,1.5,6].map(n=>[`count ${n}`,d=>d.enemies.enemies[0].intents[0].effects=[{op:'makeTempCardInDiscard',card:'dazed',value:n}]]),
 ['unknown generated card',d=>d.enemies.enemies[0].intents[0].effects=[{op:'makeTempCardInDiscard',card:'unknown',value:2}]],
]) test(`status ABI rejects ${label}`,()=>{const d=bundle();mutate(d);assert.ok(validateContent(d).length);});
