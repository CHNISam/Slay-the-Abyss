import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('small Spike Slime A0 declares sampled HP and a rolled fixed attack',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='spike_slime_s');
  assert.deepEqual(e.ai,{kind:'rolled_attack',attackIntent:'spike_slime_s_1',rollRange:100});
  assert.deepEqual(e.hpRange,{min:10,max:14});assert.equal(e.intents.length,1);
  assert.deepEqual(e.intents[0].effects,[{op:'damage',value:5}]);assert.deepEqual(validateContent(data),[]);
});
for(const [name,mutate,expected] of [
  ['unknown field',a=>a.guess=1,/ai.guess/],
  ['unknown attack',a=>a.attackIntent='missing',/attackIntent/],
  ['missing attack',a=>delete a.attackIntent,/attackIntent/],
  ['zero range',a=>a.rollRange=0,/rollRange/],
  ['fractional range',a=>a.rollRange=99.5,/rollRange/]
]) test(`rejects small Spike Slime ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='spike_slime_s');
  assert(e.ai,'missing small Spike Slime policy');mutate(e.ai);assert.match(validateContent(data).join('\n'),expected);
});
test('rejects small Spike Slime policy referencing a nonattack intent',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='spike_slime_s');
  assert(e.ai,'missing small Spike Slime policy');e.intents[0].kind='debuff';assert.match(validateContent(data).join('\n'),/attackIntent/);
});
