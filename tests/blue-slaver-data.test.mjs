import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('Blue A0 decision contract declares 40 boundary and keeps verified action payloads',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='blue_slaver');
  assert.deepEqual(e.ai,{kind:'blue_slaver',stabIntent:'blue_slaver_1',rakeIntent:'blue_slaver_2',rollRange:100,stabCutoff:40});
  assert.deepEqual(e.hpRange,{min:46,max:50});
  assert.deepEqual(e.intents[0].effects,[{op:'damage',value:12}]);
  assert.deepEqual(e.intents[1].effects,[{op:'damage',value:7},{op:'applyStatus',status:'weak',value:1}]);
  assert.deepEqual(validateContent(data),[]);
});
for(const [name,mutate,expected] of [
  ['unknown field',a=>a.guess=1,/ai.guess/],
  ['unknown Stab',a=>a.stabIntent='missing',/stabIntent/],
  ['missing Rake',a=>delete a.rakeIntent,/rakeIntent/],
  ['identical moves',a=>a.rakeIntent=a.stabIntent,/distinct/],
  ['zero range',a=>a.rollRange=0,/rollRange/],
  ['fractional cutoff',a=>a.stabCutoff=39.5,/stabCutoff/],
  ['cutoff outside range',a=>a.stabCutoff=101,/cutoff/]
]) test(`rejects Blue ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='blue_slaver');
  assert(e.ai,'missing Blue policy');mutate(e.ai);assert.match(validateContent(data).join('\n'),expected);
});
test('rejects Blue references to a nonattack intent',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='blue_slaver');
  assert(e.ai,'missing Blue policy');e.intents[1].kind='buff';assert.match(validateContent(data).join('\n'),/rakeIntent/);
});
