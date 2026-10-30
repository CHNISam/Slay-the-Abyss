import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import {preM3EventDeliverySource} from './helpers/m3-event-delivery-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {relicRound3Composition as proof,preRelicRound3CompositionSource as project} from './helpers/relic-round3-composition.mjs';
import {requireRelicCompletionSource,preRelicCompletionSource,relicCompletionInverse} from './helpers/relic-completion-inverse.mjs';
import {round3CatalogProof,preRound3CatalogSource} from './helpers/round3-catalog-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const read=p=>preM3EventDeliverySource(p,preNativeMonsterArtSource(p,readFileSync(p,'utf8'))).replaceAll('\r\n','\n');
test('both round-three composition arrows recover complete Git-locked target blobs and preserve frozen witnesses',()=>{
 assert.deepEqual(Object.values(proof.targets).map(target=>target.commit),[
  '7b9ba4ab9af438a1e875f1883b27469ee164eb31','157cd1a2c9d3e1cb5c40e374a49840dda7e103f1',
 ]);
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),previous=project(path,current,target);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(previous),binding.beforeSha256);
  assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),binding.beforeGitBlobSha1);
  assert.equal(project(path,current.replaceAll('\n','\r\n'),target),previous);
  assert.equal(project(path,previous,target),previous);
  assert.equal(project('unregistered.lua',current,target),current);
  assert.equal(project(path,null,target),null);
  requireRelicCompletionSource(path,current);
  assert.equal(hash(preRelicCompletionSource(path,current)),relicCompletionInverse.files[path].beforeSha256);
  if(round3CatalogProof.files[path]){
   assert.equal(hash(project(path,current,'round3')),round3CatalogProof.files[path].afterSha256);
   assert.equal(hash(preRound3CatalogSource(path,current)),round3CatalogProof.files[path].beforeSha256);
  }
 }
});
test('both round-three arrows refuse unknown partial duplicated moved altered and cross-path bytes',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),mutants=[current+'\n',current.slice(1),current+current];
  for(const hunk of binding.hunks){
   const lines=current.split('\n');
   for(const replacement of [[],hunk.before,[...hunk.after,...hunk.after],['-- unreviewed round-three hunk']]){
    const changed=[...lines];changed.splice(hunk.at,hunk.after.length,...replacement);mutants.push(changed.join('\n'));
   }
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);mutants.push(moved.join('\n'));
  }
  for(const mutant of new Set(mutants))if(mutant!==current)assert.equal(project(path,mutant,target),mutant);
  for(const other of Object.keys(files).filter(other=>other!==path))assert.equal(project(path,read(other),target),read(other));
 }
});
