import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { contentFiles, validateContent } from '../scripts/validate-data.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
const fixture = () => Object.fromEntries(contentFiles.map(file => [file, JSON.parse(readFileSync(new URL(`../data/${file}.json`, import.meta.url), 'utf8'))]));
const pair = (value = 3) => ['weak','vulnerable'].map(status => ({op:'applyStatusAll',status,value,targetGroup:'weak_then_vulnerable'}));
const card = data => data.cards.cards.find(card => card.id === 'shockwave');
for (const amount of [1,3,5,2147483647]) test(`card and upgrade accept one bounded pair ${amount}`, () => {
  const d=fixture();card(d).effects=pair(amount);card(d).upgrade.effects=pair(amount);
  assert.deepEqual(validateContent(d), []);
});
test('only real Shockwave variants opt in; serialization preserves the two flat presentation indices', () => {
  const d=fixture(); const c=card(d);
  assert.equal(c.cost,2);assert.equal(c.exhaust,true);assert.equal(c.type,'skill');assert.equal(c.rarity,'uncommon');
  assert.deepEqual(c.effects,pair(3));assert.deepEqual(c.upgrade.effects,pair(5));
  const opted=d.cards.cards.filter(c=>[...(c.effects||[]),...(c.upgrade?.effects||[])].some(e=>Object.hasOwn(e,'targetGroup')));
  assert.deepEqual(opted.map(c=>c.id),['shockwave']);
  assert.match(toLua(c.effects),/targetGroup/);
});
const bad = [
  ['orphan', p=>p.pop()], ['unmarked first',p=>delete p[0].targetGroup], ['unmarked second',p=>delete p[1].targetGroup],
  ['separated',p=>p.splice(1,0,{op:'energy',value:1})], ['three members',p=>p.push({...p[0]})],
  ['duplicate group',p=>p.push(...pair())], ['reverse',p=>p.reverse()], ['duplicate weak',p=>p[1].status='weak'],
  ['wrong status',p=>p[0].status='frail'], ['wrong op',p=>p[0].op='gainStatus'], ['unequal',p=>p[1].value=5],
  ['sparse',p=>delete p[0]], ['hidden after hole',p=>{p[3]=p[0];delete p[0]}],
  ['non-index marker',p=>p.extra=pair()[0]], ['container marker',p=>p.targetGroup='weak_then_vulnerable'],
  ['non-index ordinary field',p=>p.extra=false], ['nonobject member',p=>p.push(null)],
];
for (const key of ['target','times','then','if','extra']) bad.push([`extra ${key}`,p=>p[0][key]=false]);
for (const value of [false,0,'','other',{},[],null]) bad.push([`marker ${JSON.stringify(value)}`,p=>p.forEach(e=>e.targetGroup=value)]);
for (const value of [-1,0,0.5,NaN,Infinity,-Infinity,'3',2147483648]) bad.push([`amount ${value}`,p=>p.forEach(e=>e.value=value)]);
for (const [name, mutate] of bad) test(`schema rejects ${name}`, () => {
  const d=fixture(),p=pair(); mutate(p);card(d).effects=p;
  assert.match(validateContent(d).join('\n'),/targetGroup|target group/);
});
for (const scope of ['enemy','potion','relic','nested','upgrade-nested']) test(`schema rejects group in ${scope}`, () => {
  const d=fixture();
  if(scope==='enemy') d.enemies.enemies[0].intents[0].effects=pair();
  else if(scope==='potion') d.potions.potions[0].effects=pair();
  else if(scope==='relic') d.relics.relics.find(r=>r.id==='burning_blood').effects=pair();
  else (scope==='nested'?card(d):card(d).upgrade).effects=[{op:'damage',value:1},{op:'conditional',if:'target_vulnerable',then:pair()}];
  assert.match(validateContent(d).join('\n'),/targetGroup|target group/);
});
test('legal preceding and following effects remain permitted', () => {
  const d=fixture();card(d).effects=[{op:'energy',value:1},...pair(),{op:'block',value:4}];assert.deepEqual(validateContent(d),[]);
});
test('legacy unmarked effects still use their previous numeric range', () => {
  const d=fixture();card(d).effects=pair(0).map(({targetGroup,...e})=>e);assert.deepEqual(validateContent(d),[]);
});

for (const scope of ['slimed','regret','unplayable','inactive-intent','shop-relic']) test(`schema rejects false container marker on empty ${scope}`, () => {
  const d=fixture();
  const value=[];value.targetGroup=false;
  if(scope==='inactive-intent') {
    const intent=d.enemies.enemies.flatMap(e=>e.intents).find(i=>i.kind==='sleep');intent.effects=value;
  } else if(scope==='shop-relic') d.relics.relics[0].effects=value;
  else d.cards.cards.find(c=>scope==='unplayable'?c.type==='status'&&c.cost===-2:c.id===scope).effects=value;
  assert.match(validateContent(d).join('\n'),/targetGroup|target group/);
});

for (const marked of [false,true]) test(`deep effects preserve bounded validation without recursive discovery: marker=${marked}`, () => {
  const d=fixture();
  let effects=marked?pair():[{op:'energy',value:1}];
  for(let i=0;i<10000;i++) effects=[{op:'conditional',if:'target_vulnerable',then:effects}];
  card(d).effects=effects;
  const errors=validateContent(d);
  assert.ok(errors.some(e=>e.endsWith('conditional nesting exceeds 8')));
  if(marked) assert.ok(errors.some(e=>e.includes('targetGroup')));
  else assert.equal(errors.length,1);
});
