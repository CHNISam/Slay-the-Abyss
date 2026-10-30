import test from 'node:test';
import assert from 'node:assert/strict';
import {preRelicRound3CompositionSource} from './helpers/relic-round3-composition.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {relicArtComposition as proof,preRelicArtCompositionSource as project} from './helpers/relic-art-composition.mjs';
import {requireRelicCompletionSource,preRelicCompletionSource,relicCompletionInverse} from './helpers/relic-completion-inverse.mjs';
import {projectArtPerfSource,artPerfSourceComposition} from './helpers/art-perf-source-composition.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const read=p=>preRelicRound3CompositionSource(p,readFileSync(p,'utf8'),'relic').replaceAll('\r\n','\n');
test('both exact art/relic arrows recover independent complete identities without changing prior witnesses',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),previous=project(path,current,target);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(previous),binding.beforeSha256);
  assert.equal(project(path,current.replaceAll('\n','\r\n'),target),previous);
  assert.equal(project(path,previous,target),previous);
  assert.equal(project('unregistered.lua',current,target),current);
  assert.equal(project(path,null,target),null);
  requireRelicCompletionSource(path,current);
  assert.equal(hash(preRelicCompletionSource(path,current)),relicCompletionInverse.files[path].beforeSha256);
  const art=artPerfSourceComposition.files[path];
  if(art)for(const side of ['art','perf'])assert.equal(hash(projectArtPerfSource(path,current,side)),art.targets[side].sha256);
 }
});
test('both art/relic arrows refuse altered removed duplicated moved partial and cross-path sources',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),mutants=[current+'\n',current.slice(1),current+current];
  for(const hunk of binding.hunks){
   const lines=current.split('\n');
   for(const replacement of [[],hunk.before,[...hunk.after,...hunk.after],['-- unreviewed art/relic hunk']]){
    const changed=[...lines];changed.splice(hunk.at,hunk.after.length,...replacement);mutants.push(changed.join('\n'));
   }
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);mutants.push(moved.join('\n'));
  }
  for(const mutant of new Set(mutants))if(mutant!==current)assert.equal(project(path,mutant,target),mutant);
  for(const other of Object.keys(files).filter(other=>other!==path))assert.equal(project(path,read(other),target),read(other));
 }
});
