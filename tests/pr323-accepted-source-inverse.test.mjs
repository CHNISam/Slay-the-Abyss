import {projectArtPerfSource} from './helpers/art-perf-source-composition.mjs';
import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import {preRound2UiSource,round2UiSourceLayer,round2UiAddedPaths} from './helpers/round2-ui-source-inverse.mjs';
import {preRelicRound2CompositionSource} from './helpers/relic-round2-composition.mjs';
import {preRelicViewUiSource} from './helpers/relic-view-ui-inverse.mjs';
import {preHeroVisualSource} from './helpers/hero-visual-source-inverse.mjs';
import {preEventProductionSource} from './helpers/event-production-source-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import {preNestedSnapshotOwnerSource} from './helpers/nested-command-snapshot-owner-inverse.mjs';
import {prePlayerDeathSource} from './helpers/player-death-transition-inverse.mjs';
import {preDeathSettlementGuardSource} from './helpers/death-settlement-guard-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {pr323AcceptedSourceInverse as proof,preAcceptedPr323Source,preOriginalPr323Source,requirePr323Source,normalizePr323CompositionSource,requireHistoricalPr323Source,projectHistoricalPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import {preCompositeBattleMaxHpConfig} from './helpers/battle-max-hp-config-inverse.mjs';
import {preNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import {preRunMaxHpConfig} from './helpers/run-max-hp-config-inverse.mjs';
import {preCoreArchitectureSource} from './helpers/core-architecture-inverse.mjs';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
// Historical replay inputs only. Current Lua fixtures run in their normal
// suites; later changes to their registrar are not PR323 composition inputs.
const historicalFixtures=JSON.parse(gunzipSync(readFileSync(new URL('./fixtures/pr323-historical-fixtures.json.gz',import.meta.url))));
assert.equal(historicalFixtures.sourceCommit,'98fef95d047652aa6a8880241ddff28ef320a484');
assert.deepEqual(Object.keys(historicalFixtures.files),Object.keys(proof.files).filter(path=>path.startsWith('tests/lua/')));
assert.deepEqual(Object.keys(historicalFixtures.maintainedSources),['src/lua/abyss_battle_input_state.lua','src/lua/abyss_battle_target_bindings.lua']);
for(const [path,binding]of Object.entries({...historicalFixtures.files,...historicalFixtures.maintainedSources})){
 assert.equal(hash(binding.source),binding.sourceSha256,'complete original fixture input: '+path);
 assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(binding.source)}\0`).update(binding.source).digest('hex'),binding.gitBlob,'original Git blob: '+path);
}
// Actor lifecycle maintenance belongs to current summon/manager scenarios.
// The original PR323 fixture already contains its complete combined source.
const historicalActorPath='src/lua/abyss_battle_render_actors.lua';
const read=path=>path===historicalActorPath?normalize(proof.files[path].originalSource):preNestedSnapshotOwnerSource(path,prePlayerDeathSource(path,preDeathSettlementGuardSource(path,normalizePr323CompositionSource(path,normalize(preEventProductionSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,historicalFixtures.files[path]?.source??historicalFixtures.maintainedSources[path]?.source??readFileSync(path,'utf8')))))))));
const historicalAccepted=(path,source)=>projectHistoricalPr323Source(path,source,'accepted');
const historicalOriginal=(path,source)=>projectHistoricalPr323Source(path,source,'original');
test('combined PR323 sources recover both complete accepted20a and original323 witnesses',()=>{
 for(const [path,binding]of Object.entries(proof.files)){
   const current=read(path);
  requireHistoricalPr323Source(path,current);
  assert.equal(hash(current),binding.afterSha256,path);
  // Keep a live bridge for production sources. The full historical matrix
  // uses the same pure body without repeatedly revalidating unrelated owners.
  if(path!==historicalActorPath&&!historicalFixtures.files[path]&&!historicalFixtures.maintainedSources[path])assert.equal(preAcceptedPr323Source(path,readFileSync(path,'utf8')),binding.acceptedSource===null?null:normalize(binding.acceptedSource),path+' live bridge');
  if(path==='config/architecture.json'){
   requirePr323Source(path,readFileSync(path,'utf8'));
   assert.equal(preOriginalPr323Source(path,readFileSync(path,'utf8')),normalize(binding.originalSource),'public original target keeps its current-source bridge');
  }
  for(const [project,target]of [[historicalAccepted,'accepted'],[historicalOriginal,'original']]){
   const expected=binding[target+'Source']===null?null:normalize(binding[target+'Source']);
   assert.equal(project(path,current),expected,path+' '+target);
   assert.equal(project(path,current.replaceAll('\n','\r\n')),expected,path+' CRLF '+target);
   assert.equal(project(path,null),null,path+' absent historical source');
  }
 }
});
test('partial, appended, missing and cross-path sources never acquire composition permission',()=>{
 const entries=Object.entries(proof.files);
 for(const [path,binding]of entries){
   const current=read(path);
  for(const changed of [current+'\n-- unrelated drift\n',current.slice(1)]){
   assert.notEqual(changed,current);
   assert.throws(()=>requireHistoricalPr323Source(path,changed),/unreviewed integrated/);
   assert.equal(historicalAccepted(path,changed),changed,'unknown bytes stay exposed');
   assert.equal(historicalOriginal(path,changed),changed,'unknown bytes stay exposed');
  }
  assert.throws(()=>requireHistoricalPr323Source(path,null),/must exist/);
  const foreign=entries.find(([other,b])=>other!==path&&b.afterSha256!==binding.afterSha256);
   if(foreign)assert.throws(()=>requireHistoricalPr323Source(path,read(foreign[0])),/unreviewed integrated/);
 }
 assert.throws(()=>requirePr323Source('unregistered-source.lua','return {}\n'),/registered/);
 assert.equal(preAcceptedPr323Source('unregistered-source.lua','return {}\n'),'return {}\n');
 const path='config/architecture.json',current=read(path);
 for(const changed of [current+'\n-- unrelated drift\n',current.slice(1)]){
  assert.throws(()=>requirePr323Source(path,changed),/unreviewed integrated/);
  assert.equal(preAcceptedPr323Source(path,changed),changed);
  assert.equal(preOriginalPr323Source(path,changed),changed);
 }
 assert.throws(()=>projectHistoricalPr323Source(path,current,'unknown'),/registered PR323 historical target/);
});
test('config-only historical adapters never project away unrelated current production modules',()=>{
 const path='src/lua/abyss_relic_names.lua',current=normalize(preEventProductionSource(path,preHeroVisualSource(path,preRelicViewUiSource(path,readFileSync(path,'utf8')))));
 assert.equal(proof.files[path].acceptedSource,null,'this live module did not exist in accepted20a');
 assert.equal(preAcceptedPr323Source(path,current),null,'only the explicit outer historical projection removes it');
 for(const adapter of [preRosterConfigSource,preCompositeBattleMaxHpConfig,preNodesBattleMaxHpConfig,preRunMaxHpConfig,preCoreArchitectureSource])
  assert.equal(adapter(path,current),current,'thin config adapters retain their original path ownership');
});

test('round-two UI inverse recovers exact prior hosts and config without replacing frozen witnesses',()=>{
 for(const [path,binding]of Object.entries(round2UiSourceLayer.files)){
  const current=normalize(preRelicRound2CompositionSource(path,projectArtPerfSource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8')),'perf'),'round2'));
  assert.equal(hash(current),binding.afterSha256,path+' complete current source');
  const previous=preRound2UiSource(path,current);
  assert.equal(previous===null?null:hash(previous),binding.beforeSha256,path+' exact a7 source');
  assert.equal(preRound2UiSource(path,current.replaceAll('\n','\r\n')),previous,path+' CRLF');
  assert.equal(preRound2UiSource(path,previous),previous,path+' no repeated inverse');
  assert.equal(preRound2UiSource(path,null),null,path+' missing source remains exposed');
  for(const mutant of [current+'\n-- unrelated drift\n',current.slice(1),current+current]){
   assert.equal(preRound2UiSource(path,mutant),mutant,path+' unknown bytes cannot acquire historical permission');
  }
  if(binding.hunks.length){
   const hunk=binding.hunks.find(h=>h.after.length>0);
   const after=hunk.after.join('\n'),before=hunk.before.join('\n');
   for(const mutant of [current.replace(after,before),current.replace(after,after+'\n'+after)]){
    assert.notEqual(mutant,current,path+' partial/duplicated inverse is a real mutation');
    assert.equal(preRound2UiSource(path,mutant),mutant,path+' partial or duplicate patches stay exposed');
   }
  }
 }
 assert.equal(preRound2UiSource('unregistered.lua','return {}'),'return {}');
});

test('round-two UI historical permission binds both extracted modules and rejects missing or drifting responsibilities',()=>{
 const sources=Object.fromEntries(round2UiAddedPaths.map(path=>[path,normalize(projectArtPerfSource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8')),'perf'))]));
 for(const path of Object.keys(round2UiSourceLayer.files)){
  const current=normalize(preRelicRound2CompositionSource(path,projectArtPerfSource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8')),'perf'),'round2'));
  for(const changed of round2UiAddedPaths){
   for(const mutant of [sources[changed]+'\n-- drift\n',sources[changed].slice(1),sources[changed]+sources[changed]]){
    assert.throws(()=>preRound2UiSource(path,current,{readSource:key=>key===changed?mutant:sources[key]}),/linked module drift/);
   }
   assert.throws(()=>preRound2UiSource(path,current,{readSource:key=>{if(key===changed)throw new Error('missing');return sources[key];}}),/linked module missing/);
  }
 }
});
