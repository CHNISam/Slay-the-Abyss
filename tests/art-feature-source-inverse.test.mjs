import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {preRelicArtFeatureCompositionSource} from './helpers/relic-art-feature-composition.mjs';
import {preRelicArtCompositionSource} from './helpers/relic-art-composition.mjs';
import {createHash} from 'node:crypto';
import {existsSync,mkdirSync,mkdtempSync,readFileSync,rmSync,symlinkSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import {artFeatureSourceLayer as proof,artFeatureAddedPaths,preArtFeatureSource,prepareArtFeatureRetirement} from './helpers/art-feature-source-inverse.mjs';
import {artPerfSourceComposition,projectArtPerfSource} from './helpers/art-perf-source-composition.mjs';
import {readyArtSourceLayer,preReadyArtSource} from './helpers/ready-art-source-inverse.mjs';
import {round2UiAddedPaths} from './helpers/round2-ui-source-inverse.mjs';
import {preRound3CatalogSource} from './helpers/round3-catalog-source-inverse.mjs';
import {prepareBattleLifeModuleRetirement} from './helpers/battle-life-source-inverse.mjs';

const read=path=>preRelicArtCompositionSource(path,preRelicArtFeatureCompositionSource(path,preNativeMonsterArtSource(path,readFileSync(path,'utf8')),'artFeature'),'art').replaceAll('\r\n','\n');
const hash=source=>source===null?null:createHash('sha256').update(source).digest('hex');
const put=(directory,path,source)=>{const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);};
const temporary=()=>mkdtempSync(join(tmpdir(),'abyss-art-feature-inverse-'));

test('exact feature/fallback inverse binds every current source and restores complete baseline identities',()=>{
 assert.equal(proof.baseCommit,'1bfca6261044b92f8065bb83668c358b0a2627da');
 assert.ok(artFeatureAddedPaths.length>0,'added feature owner is explicitly bound');
 for(const path of ['scripts/native-candidate-ui-cache.mjs','scripts/native-script-inventory.mjs',
  'scripts/native-script-batch.mjs','scripts/art/performance-pack.mjs',
  'art/performance/selection-budget-v1.json','art/performance/background-budget-v1.json']){
  assert.ok(artFeatureAddedPaths.includes(path),'complete merged feature owner is bound: '+path);
 }
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path),before=preArtFeatureSource(path,current);
  assert.equal(hash(current),binding.afterSha256,'complete approved current source: '+path);
  assert.equal(hash(before),binding.beforeSha256,'complete pre-feature baseline: '+path);
  assert.equal(preArtFeatureSource(path,current.replaceAll('\n','\r\n')),before,'native CRLF: '+path);
  assert.equal(preArtFeatureSource(path,before),before,'idempotent baseline: '+path);
  assert.equal(before===null,artFeatureAddedPaths.includes(path),'only new source becomes absent: '+path);
  assert.equal(preArtFeatureSource(path,undefined),undefined);
 }
 assert.equal(preArtFeatureSource('src/lua/unregistered.lua','return {}\n'),'return {}\n');
});

test('unknown, partial, duplicate, cross-path and reordered feature sources remain exposed',()=>{
 const entries=Object.entries(proof.files);
 for(const [path,binding]of entries){
  const current=read(path);
  const mutants=[current+'\n-- future\n',current.slice(1),current+current];
  const lines=current.split('\n'),other=lines.findIndex(line=>line!==lines[0]);
  if(other>0){[lines[0],lines[other]]=[lines[other],lines[0]];mutants.push(lines.join('\n'));}
  for(const hunk of binding.hunks){
   const partial=current.split('\n');partial.splice(hunk.at,hunk.after.length,...hunk.before);
   if(hash(partial.join('\n'))!==binding.beforeSha256)mutants.push(partial.join('\n'));
  }
  const foreign=entries.find(([otherPath])=>otherPath!==path&&read(otherPath)!==current);
  if(foreign)mutants.push(read(foreign[0]));
  for(const mutant of mutants){
   assert.notEqual(hash(mutant),binding.afterSha256);
   assert.equal(preArtFeatureSource(path,mutant),mutant,'no wildcard feature projection: '+path);
   assert.equal(projectArtPerfSource(path,mutant,'art'),mutant,'unknown stays visible to old art guards: '+path);
   assert.equal(projectArtPerfSource(path,mutant,'perf'),mutant,'unknown stays visible to old performance guards: '+path);
  }
 }
});

test('recognized feature hosts bind every added owner and reject missing or drifting linked sources',()=>{
 for(const [path,binding]of Object.entries(proof.files)){
  if(binding.beforeSha256===null)continue;
  for(const changed of artFeatureAddedPaths){
   assert.throws(()=>preArtFeatureSource(path,read(path),{readSource:key=>key===changed?read(key)+'\n// drift\n':read(key)}),/linked source drift/);
   assert.throws(()=>preArtFeatureSource(path,read(path),{readSource:key=>{if(key===changed)throw Error('missing');return read(key);}}),/linked source missing/);
   assert.throws(()=>preArtFeatureSource(path,read(path),{readSource:key=>key===changed?null:read(key)}),/complete art-feature linked source/);
  }
 }
});

test('feature normalization precedes both frozen art/performance and ready-art source chains',()=>{
 for(const [path,binding]of Object.entries(artPerfSourceComposition.files)){
  const current=read(path),baseline=preRound3CatalogSource(path,preArtFeatureSource(path,current));
  assert.equal(hash(baseline),binding.currentSha256,'old art/performance composition bytes remain immutable: '+path);
  for(const target of ['art','perf']){
   assert.equal(hash(projectArtPerfSource(path,current,target)),binding.targets[target].sha256);
   assert.equal(projectArtPerfSource(path,current,target),projectArtPerfSource(path,baseline,target));
  }
 }
 for(const [path,binding]of Object.entries(readyArtSourceLayer.files)){
  const current=read(path);
  assert.equal(hash(projectArtPerfSource(path,current,'art')),binding.afterSha256,'old ready-art witness remains immutable: '+path);
  assert.equal(hash(preReadyArtSource(path,current)),binding.beforeSha256,'old ready-art inverse still exact: '+path);
 }
});

test('combined feature and old-module retirement validates all owners before removing any destination',()=>{
 const directory=temporary();
 const paths=[...artFeatureAddedPaths,'src/lua/abyss_card_art_runtime.lua',...round2UiAddedPaths,'src/lua/abyss_combat_catalog.lua'];
 const live=Object.fromEntries(paths.map(path=>[path,read(path)]));
 try{
  for(const path of paths)put(directory,path,live[path]);
  put(directory,'keep.txt','keep');
  for(const changed of paths){
   put(directory,changed,live[changed]+'\n-- unreviewed destination\n');
   assert.throws(()=>prepareBattleLifeModuleRetirement(directory),/unreviewed .* (?:added )?module destination/);
   for(const path of paths)assert.ok(existsSync(join(directory,path)),'no partial cleanup: '+path);
   put(directory,changed,live[changed]);
  }
  const retire=prepareBattleLifeModuleRetirement(directory);
  for(const path of paths)assert.ok(existsSync(join(directory,path)),'preparation never deletes: '+path);
  retire();
  for(const path of paths){assert.equal(existsSync(join(directory,path)),false);assert.equal(read(path),live[path],'live source never changes: '+path);}
  assert.equal(readFileSync(join(directory,'keep.txt'),'utf8'),'keep');
  prepareArtFeatureRetirement(directory)();
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('feature retirement revalidates destinations after preparation and before any removal',()=>{
 const directory=temporary();
 try{
  for(const path of artFeatureAddedPaths)put(directory,path,read(path));
  const retire=prepareArtFeatureRetirement(directory),changed=artFeatureAddedPaths.at(-1);
  put(directory,changed,read(changed)+'\n// changed after preparation\n');
  assert.throws(retire,/unreviewed art-feature added module destination/);
  for(const path of artFeatureAddedPaths)assert.ok(existsSync(join(directory,path)),'no destination removed before revalidation');
  put(directory,changed,read(changed));retire();
  for(const path of artFeatureAddedPaths)assert.equal(existsSync(join(directory,path)),false);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('combined retirement revalidates feature and catalog owners before old-module deletions',()=>{
 const directory=temporary(),paths=[...artFeatureAddedPaths,'src/lua/abyss_card_art_runtime.lua',...round2UiAddedPaths,'src/lua/abyss_combat_catalog.lua'];
 try{
  for(const path of paths)put(directory,path,read(path));
  const retire=prepareBattleLifeModuleRetirement(directory);
  for(const changed of [...artFeatureAddedPaths,'src/lua/abyss_combat_catalog.lua']){
   put(directory,changed,read(changed)+'\n// changed after combined preparation\n');
   assert.throws(retire,/unreviewed .* (?:added )?module destination/);
   for(const path of paths)assert.ok(existsSync(join(directory,path)),'no old or new destination removed before feature/catalog revalidation: '+path);
   put(directory,changed,read(changed));
  }
  retire();
  for(const path of paths)assert.equal(existsSync(join(directory,path)),false);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('combined retirement rejects same-byte catalog retargeting before any deletion',()=>{
 const directory=temporary(),catalog='src/lua/abyss_combat_catalog.lua';
 const paths=[...artFeatureAddedPaths,'src/lua/abyss_card_art_runtime.lua',...round2UiAddedPaths,catalog];
 try{
  for(const path of paths)put(directory,path,read(path));
  const retire=prepareBattleLifeModuleRetirement(directory),target=join(directory,catalog),alternate=join(directory,'catalog-copy.lua');
  writeFileSync(alternate,read(catalog));rmSync(target);symlinkSync(alternate,target);
  assert.throws(retire,/catalog module destination changed after preparation/);
  for(const path of paths)assert.ok(existsSync(join(directory,path)),'same-byte retargeting must not remove any owner: '+path);
  assert.equal(readFileSync(alternate,'utf8'),read(catalog));
  assert.equal(readFileSync(target,'utf8'),read(catalog));
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('feature retirement rejects live roots and symlink aliases without touching live source',()=>{
 const directory=temporary(),live=Object.fromEntries(Object.keys(proof.files).map(path=>[path,read(path)]));
 try{
  assert.throws(()=>prepareArtFeatureRetirement(process.cwd()),/separate historical destination/);
  const alias=join(directory,'live-alias');symlinkSync(process.cwd(),alias,'dir');
  assert.throws(()=>prepareArtFeatureRetirement(alias),/separate historical destination/);
  const copy=join(directory,'copy');mkdirSync(copy);
  const first=artFeatureAddedPaths[0],parent=first.split('/')[0];
  symlinkSync(join(process.cwd(),parent),join(copy,parent),'dir');
  assert.throws(()=>prepareArtFeatureRetirement(copy),/must not escape|never remove a live source/);
  for(const [path,source]of Object.entries(live))assert.equal(read(path),source,'live source remains byte-identical: '+path);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
