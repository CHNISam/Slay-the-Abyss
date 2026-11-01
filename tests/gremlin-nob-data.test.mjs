import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('Nob A0 runtime contract declares range and Enrage opening', () => {
  const data=loadContent('data'), e=data.enemies.enemies.find(e=>e.id==='gremlin_nob');
  assert.equal(e.ai?.kind,'gremlin_nob');
  assert.deepEqual(e.hpRange,{min:82,max:86});
  assert.equal(e.intents.length,3);
  assert.deepEqual(validateContent(data),[]);
});
for (const [name,mutate,expected] of [
  ['unknown field',a=>a.guess=1,/ai.guess/],
  ['unknown Bellow',a=>a.bellowIntent='missing',/bellowIntent/],
  ['attack Bellow',a=>a.bellowIntent='gremlin_nob_2',/bellowIntent/],
  ['buff Bash',a=>a.bashIntent='gremlin_nob_1',/bashIntent/],
  ['same attack intents',a=>a.rushIntent=a.bashIntent,/distinct/],
  ['zero roll range',a=>a.rollRange=0,/rollRange/],
  ['fractional cutoff',a=>a.bashCutoff=32.5,/bashCutoff/],
  ['cutoff outside range',a=>a.bashCutoff=101,/cutoff/],
]) test(`rejects Nob ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='gremlin_nob');
  assert(e.ai,'missing Nob AI');mutate(e.ai);assert.match(validateContent(data).join('\n'),expected);
});
test('Nob Bellow must grant positive Enrage',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='gremlin_nob');
  assert(e.ai,'missing Nob AI');e.intents[0].effects=[{op:'gainStatus',status:'strength',value:2}];
  assert.match(validateContent(data).join('\n'),/bellowIntent/);
});
