import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import {preM3EventDeliverySource} from './helpers/m3-event-delivery-source-inverse.mjs';
import {historicalTest as test,withHistoricalBaseline} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {relicArtFeatureComposition as proof,preRelicArtFeatureCompositionSource as project} from './helpers/relic-art-feature-composition.mjs';
import {artFeatureSourceLayer,preArtFeatureSource} from './helpers/art-feature-source-inverse.mjs';
import {requireRelicCompletionSource,preRelicCompletionSource,relicCompletionInverse} from './helpers/relic-completion-inverse.mjs';
const path='scripts/verify-launch-content.mjs';
const current=withHistoricalBaseline(()=>preM3EventDeliverySource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8'))).replaceAll('\r\n','\n'));
const hash=s=>createHash('sha256').update(s).digest('hex');
test('single-path art-feature/relic composition restores both complete Git-locked identities and frozen witnesses',()=>{
 for(const [target,{files}]of Object.entries(proof.targets)){
  assert.deepEqual(Object.keys(files),[path]);
  const binding=files[path],previous=project(path,current,target);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(previous),binding.beforeSha256);
  assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),binding.beforeGitBlobSha1);
  assert.equal(project(path,current.replaceAll('\n','\r\n'),target),previous);
  assert.equal(project(path,previous,target),previous);
  assert.equal(project('scripts/other.mjs',current,target),current);
  assert.equal(project(path,null,target),null);
 }
 requireRelicCompletionSource(path,current);
 assert.equal(hash(preRelicCompletionSource(path,current)),relicCompletionInverse.files[path].beforeSha256);
 assert.equal(hash(project(path,current,'artFeature')),artFeatureSourceLayer.files[path].afterSha256);
 assert.equal(hash(preArtFeatureSource(path,current)),artFeatureSourceLayer.files[path].beforeSha256);
});
test('both arrows refuse unknown partial removed duplicated altered and moved sources',()=>{
 for(const [target,{files}]of Object.entries(proof.targets)){
  const mutants=[current+'\n',current.slice(1),current+current];
  for(const hunk of files[path].hunks){
   const lines=current.split('\n');
   for(const replacement of [[],hunk.before,[...hunk.after,...hunk.after],['// unreviewed composition']]){
    const changed=[...lines];changed.splice(hunk.at,hunk.after.length,...replacement);mutants.push(changed.join('\n'));
   }
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);mutants.push(moved.join('\n'));
  }
  for(const mutant of new Set(mutants))if(mutant!==current){
   assert.equal(project(path,mutant,target),mutant);
   assert.equal(project(path,mutant,target),mutant,'cached unknown input retains its complete original bytes');
  }
 }
});
test('new proof is deeply immutable and warm pure memo never suppresses dynamic linked-source validation',()=>{
 const frozen=value=>{if(value&&typeof value==='object'){assert.ok(Object.isFrozen(value));Object.values(value).forEach(frozen);}};
 frozen(proof);
 assert.throws(()=>proof.targets.relic.files[path].hunks[0].after.push('unreviewed'),TypeError);
 preArtFeatureSource(path,current);
 let reads=0;
 for(let i=0;i<2;i++)assert.throws(()=>preArtFeatureSource(path,current,{readSource:()=>{reads++;throw Error('missing');}}),/linked source missing/);
 assert.equal(reads,2);
});
