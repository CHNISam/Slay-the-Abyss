import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

for(const [id,kind,hp,min,max,effects] of [
  ['fat_gremlin','rolled_attack',15,13,17,[{op:'damage',value:4},{op:'applyStatus',status:'weak',value:1}]],
  ['sneaky_gremlin','opening_roll_attack',12,10,14,[{op:'damage',value:9}]]
]) test(`${id} keeps verified A0 values and declares the source-specific roll policy`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id===id);
  assert.deepEqual(e.ai,{kind,attackIntent:`${id}_1`,rollRange:100});assert.equal(e.hp,hp);
  assert.deepEqual(e.hpRange,{min,max});assert.equal(e.intents.length,1);assert.deepEqual(e.intents[0].effects,effects);
  assert.deepEqual(validateContent(data),[]);
});
for(const [name,mutate,expected] of [
  ['unknown field',a=>a.guess=1,/ai.guess/],
  ['unknown attack',a=>a.attackIntent='missing',/attackIntent/],
  ['missing attack',a=>delete a.attackIntent,/attackIntent/],
  ['zero range',a=>a.rollRange=0,/rollRange/],
  ['fractional range',a=>a.rollRange=99.5,/rollRange/]
]) test(`rejects opening-only attack ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='sneaky_gremlin');
  assert(e.ai,'missing Sneaky policy');mutate(e.ai);assert.match(validateContent(data).join('\n'),expected);
});
test('opening-only policy must reference an attack',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='sneaky_gremlin');
  assert(e.ai,'missing Sneaky policy');e.intents[0].kind='buff';assert.match(validateContent(data).join('\n'),/attackIntent/);
});
