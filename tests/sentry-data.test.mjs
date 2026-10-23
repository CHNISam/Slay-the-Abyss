import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('Sentry A0 declares source HP, Artifact and genuine Dazed Bolt',()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='sentry');
  assert.deepEqual(e.hpRange,{min:38,max:42});
  assert.deepEqual(e.ai,{kind:'sentry',beamIntent:'sentry_1',boltIntent:'sentry_2',artifactStacks:1,rollRange:100});
  assert.deepEqual(e.intents[0].effects,[{op:'damage',value:9}]);
  assert.deepEqual(e.intents[1].effects,[{op:'makeTempCardInDiscard',card:'dazed',value:2}]);
  assert.deepEqual(validateContent(data),[]);
});
for(const [name,mutate,expected] of [
  ['unknown field',e=>e.ai.guess=1,/ai.guess/],
  ['unknown Beam',e=>e.ai.beamIntent='missing',/beamIntent/],
  ['unknown Bolt',e=>e.ai.boltIntent='missing',/boltIntent/],
  ['debuff Beam',e=>e.ai.beamIntent='sentry_2',/beamIntent/],
  ['attack Bolt',e=>e.ai.boltIntent='sentry_1',/boltIntent/],
  ['zero Artifact',e=>e.ai.artifactStacks=0,/artifactStacks/],
  ['fractional Artifact',e=>e.ai.artifactStacks=.5,/artifactStacks/],
  ['zero roll range',e=>e.ai.rollRange=0,/rollRange/],
  ['old Weak replacement',e=>e.intents[1].effects=[{op:'applyStatus',status:'weak',value:1}],/boltIntent/],
  ['missing Dazed cards',e=>e.intents[1].effects[0].card='missing',/card/],
]) test(`rejects Sentry ${name}`,()=>{
  const data=loadContent('data'),e=data.enemies.enemies.find(e=>e.id==='sentry');
  mutate(e);assert.match(validateContent(data).join('\n'),expected);
});
