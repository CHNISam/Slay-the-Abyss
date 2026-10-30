import {preNativeMonsterArtSource} from './helpers/native-monster-art-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {preRelicRound2CompositionSource} from './helpers/relic-round2-composition.mjs';
import {preNativeEnemyThemeSource} from './helpers/native-enemy-theme-inverse.mjs';
import {createHash} from 'node:crypto';
import {existsSync,mkdirSync,mkdtempSync,readFileSync,readdirSync,rmSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import {historicalPresentationFixtures} from './helpers/historical-presentation-runner.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {relicCompletionInverse as proof,relicCompletionAddedPaths,requireRelicCompletionSource,
 tryRelicCompletionSource,preRelicCompletionSource,prepareRelicCompletionModuleRetirement,
 materializeBeforeRelicCompletionSources} from './helpers/relic-completion-inverse.mjs';
const hash=s=>s===null?null:createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
const read=path=>{
 const source=readFileSync(path,'utf8');
 // New outer-only modules remain actual production inputs for unregistered-source negatives.
 return preNativeEnemyThemeSource(path,preRelicRound2CompositionSource(path,preNativeMonsterArtSource(path,source)??source,'relic')).replaceAll('\r\n','\n');
};
test('complete relic source identities recover exact ce62 sources solely from positioned hunks',()=>{
 assert.ok(Object.keys(proof.files).length>40);
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path);requireRelicCompletionSource(path,current);
  const previous=tryRelicCompletionSource(path,current);
  assert.notEqual(previous,undefined,path);
  assert.equal(hash(current),binding.afterSha256,path);
  assert.equal(hash(previous),binding.beforeSha256,path);
  assert.equal(preRelicCompletionSource(path,current.replaceAll('\n','\r\n')),previous,path);
  assert.equal(preRelicCompletionSource(path,previous),previous,'exact historical witness remains idempotent: '+path);
  assert.equal(previous===null,binding.beforeSha256===null,'null means genuine prior absence: '+path);
 }
});
test('every registered source mutation and each removed duplicated moved or altered hunk refuses',()=>{
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path);
  const mutants=[current+'\n-- unregistered extra source\n',current.slice(1),'return {}\n'];
  for(const hunk of binding.hunks){
   const lines=current.split('\n');
   for(const replacement of [[],[...hunk.after,...hunk.after],hunk.before,['-- mutated known relic hunk']]){
    const changed=[...lines];changed.splice(hunk.at,hunk.after.length,...replacement);mutants.push(changed.join('\n'));
   }
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);mutants.push(moved.join('\n'));
  }
  for(const mutant of new Set(mutants)){
   if(hash(mutant)===binding.afterSha256)continue;
   assert.throws(()=>requireRelicCompletionSource(path,mutant),/unreviewed relic completion source/);
   assert.equal(tryRelicCompletionSource(path,mutant),undefined,'foreign bytes are not a genuine absent module: '+path);
   assert.equal(preRelicCompletionSource(path,mutant),mutant,'unknown bytes stay exposed to inner guards: '+path);
  }
 }
});
test('every unregistered production Lua source and arbitrary paths reject rather than projecting blind snapshots',()=>{
 let count=0;
 for(const name of readdirSync('src/lua')){
  const path='src/lua/'+name;if(!name.endsWith('.lua')||proof.files[path])continue;
  const mutant=readFileSync(path,'utf8')+'\n-- unexpected future source\n';count++;
  assert.throws(()=>requireRelicCompletionSource(path,mutant),/unregistered relic completion source/);
  assert.equal(tryRelicCompletionSource(path,mutant),undefined);
  assert.equal(preRelicCompletionSource(path,mutant),mutant);
 }
 assert.ok(count>100);
 assert.throws(()=>requireRelicCompletionSource('../unregistered.lua','return {}'),/unregistered/);
});
test('historical cleanup validates all truly new module bytes before any retirement',()=>{
 const directory=mkdtempSync(join(tmpdir(),'relic-completion-history-'));
 try{
  for(const path of relicCompletionAddedPaths){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,read(path));}
  assert.throws(()=>prepareRelicCompletionModuleRetirement(process.cwd()),/separate historical/);
  const last=relicCompletionAddedPaths.at(-1),target=join(directory,last);
  writeFileSync(target,read(last)+'\n-- drift\n');
  assert.throws(()=>prepareRelicCompletionModuleRetirement(directory),/unreviewed relic completion/);
  for(const path of relicCompletionAddedPaths)assert.ok(existsSync(join(directory,path)));
  writeFileSync(target,read(last));const retire=prepareRelicCompletionModuleRetirement(directory);
  for(const path of relicCompletionAddedPaths)assert.ok(existsSync(join(directory,path)));
  retire();for(const path of relicCompletionAddedPaths)assert.equal(existsSync(join(directory,path)),false);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('historical materialization restores every existing source before old builders and refuses drift before writing',()=>{
 const directory=mkdtempSync(join(tmpdir(),'relic-completion-materialize-'));
 try{
  const paths=Object.keys(proof.files),existing=paths.filter(path=>proof.files[path].beforeSha256!==null);
  for(const path of paths){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,read(path));}
  assert.throws(()=>materializeBeforeRelicCompletionSources(process.cwd()),/separate destination/);
  const last=existing.at(-1);writeFileSync(join(directory,last),read(last)+'\n-- drift\n');
  assert.throws(()=>materializeBeforeRelicCompletionSources(directory),/unreviewed relic completion source/);
  for(const path of existing.slice(0,-1))assert.equal(hash(readFileSync(join(directory,path),'utf8')),proof.files[path].afterSha256,'validation precedes every write: '+path);
  writeFileSync(join(directory,last),read(last));materializeBeforeRelicCompletionSources(directory);
  for(const path of existing)assert.equal(hash(readFileSync(join(directory,path),'utf8')),proof.files[path].beforeSha256,'complete prior source: '+path);
  for(const path of relicCompletionAddedPaths)assert.equal(hash(readFileSync(join(directory,path),'utf8')),proof.files[path].afterSha256,'addition awaits validated deferred retirement: '+path);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('current relic feature fixtures and production modules never use historical source projection',()=>{
 for(const name of readdirSync('src/lua').filter(name=>name.endsWith('.lua')))
  assert.doesNotMatch(readFileSync('src/lua/'+name,'utf8'),/relic-completion-inverse|preRelicCompletionSource/);
 for(const path of ['tests/lua/shop_relics_effects.lua','tests/lua/shop_relics_acquisition.lua',
  'tests/lua/shop_relics_pending_ui.lua','tests/lua/boss_relics_missing.lua',
  'tests/lua/uncommon_relics_effects.lua','tests/lua/rare_relics_hooks.lua']){
  assert.ok(!historicalPresentationFixtures.includes(path),'current relic fixture is never historically materialized: '+path);
  assert.doesNotMatch(read(path),/preRelicCompletionSource|relic-completion-inverse/);
 }
});
test('Sensory Stone direct runtime keeps the full new script while only historical proof input recovers old bytes',()=>{
 const path='tests/lua/sensory_stone_outcomes.lua',current=read(path),binding=proof.files[path];
 assert.ok(binding,'single explicitly owned PR323 fixture source');
 assert.equal(hash(current),binding.afterSha256,'runtime script body is the full current after identity');
 assert.equal(hash(preRelicCompletionSource(path,current)),binding.beforeSha256,'historical proof alone receives exact ce62 body');
 assert.notEqual(binding.afterSha256,binding.beforeSha256);
 assert.ok(!historicalPresentationFixtures.includes(path),'ordinary runLua never historically materializes this runtime fixture');
 const result=runLua(path);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.equal(hash(read(path)),binding.afterSha256,'direct runtime execution leaves every current assertion intact');
});
