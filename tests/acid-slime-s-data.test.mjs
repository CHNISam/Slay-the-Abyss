import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('small Acid Slime A0 declares randomized opening and alternating source actions',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='acid_slime_s');
  assert.deepEqual(e.ai,{kind:'acid_slime_s',tackleIntent:'acid_slime_s_1',weakIntent:'acid_slime_s_2',rollRange:100});
  assert.deepEqual(e.hpRange,{min:8,max:12});
  assert.deepEqual(e.intents[0].effects,[{op:'damage',value:3}]);
  assert.deepEqual(e.intents[1].effects,[{op:'applyStatus',status:'weak',value:1}]);
  assert.deepEqual(validateContent(data),[]);
});
for(const [name,mutate,expected] of [
  ['unknown field',a=>a.guess=1,/ai.guess/],
  ['unknown Tackle',a=>a.tackleIntent='missing',/tackleIntent/],
  ['missing Weak',a=>delete a.weakIntent,/weakIntent/],
  ['debuff Tackle',a=>a.tackleIntent=a.weakIntent,/tackleIntent/],
  ['attack Weak',a=>a.weakIntent=a.tackleIntent,/weakIntent/],
  ['zero range',a=>a.rollRange=0,/rollRange/],
  ['fractional range',a=>a.rollRange=99.5,/rollRange/]
]) test(`rejects small Acid Slime ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='acid_slime_s');
  assert(e.ai,'missing small Acid Slime policy');mutate(e.ai);assert.match(validateContent(data).join('\n'),expected);
});
