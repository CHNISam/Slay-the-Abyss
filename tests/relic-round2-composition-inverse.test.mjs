import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {preRelicRound3CompositionSource} from './helpers/relic-round3-composition.mjs';
import {preRelicArtCompositionSource} from './helpers/relic-art-composition.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {relicRound2Composition as proof,preRelicRound2CompositionSource as project} from './helpers/relic-round2-composition.mjs';
import {requireRelicCompletionSource,preRelicCompletionSource,relicCompletionInverse} from './helpers/relic-completion-inverse.mjs';
import {preRound2CanPlaySource,round2CanPlayProof} from './helpers/round2-can-play-source-inverse.mjs';
import {preRound2UiSource,round2UiSourceLayer} from './helpers/round2-ui-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const read=p=>preRelicArtCompositionSource(p,preRelicRound3CompositionSource(p,preNativeMonsterArtSource(p,readFileSync(p,'utf8')),'relic'),'relic').replaceAll('\r\n','\n');
test('both exact composition arrows retain independent whole-file identities and positioned forward reconstruction',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),previous=project(path,current,target);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(previous),binding.beforeSha256);
  assert.equal(project(path,current.replaceAll('\n','\r\n'),target),previous);
  assert.equal(project(path,previous,target),previous);
  assert.equal(project('unregistered.lua',current,target),current);
  assert.equal(project(path,null,target),null);
  if(target==='relic'&&relicCompletionInverse.files[path]){
   requireRelicCompletionSource(path,current);
   assert.equal(hash(preRelicCompletionSource(path,current)),relicCompletionInverse.files[path].beforeSha256);
  }
 }
 const path=round2CanPlayProof.path,current=read(path);
 assert.equal(hash(project(path,current,'round2')),round2CanPlayProof.afterSha256);
 assert.equal(hash(preRound2CanPlaySource(path,current)),round2CanPlayProof.beforeSha256);
 for(const path of ['config/architecture.json','src/lua/abyss_game_ui.lua']){
  const current=read(path),binding=round2UiSourceLayer.files[path];
  assert.equal(hash(project(path,current,'round2')),binding.afterSha256);
  assert.equal(hash(preRound2UiSource(path,current)),binding.beforeSha256);
 }
});
test('both composition arrows refuse every altered removed duplicated moved and cross-path hunk',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,binding]of Object.entries(files)){
  const current=read(path),mutants=[current+'\n',current.slice(1)];
  for(const hunk of binding.hunks){
   const lines=current.split('\n');
   for(const replacement of [[],hunk.before,[...hunk.after,...hunk.after],['-- unreviewed combined hunk']]){
    const changed=[...lines];changed.splice(hunk.at,hunk.after.length,...replacement);mutants.push(changed.join('\n'));
   }
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);mutants.push(moved.join('\n'));
  }
  for(const mutant of new Set(mutants)){
   if(mutant===current)continue;
   assert.equal(project(path,mutant,target),mutant);
  }
  for(const other of Object.keys(files).filter(other=>other!==path))assert.equal(project(path,read(other),target),read(other));
 }
});
