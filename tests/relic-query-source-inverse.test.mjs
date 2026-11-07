import {preDefectPlanSource} from './helpers/defect-plan-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {preCoreLifecycleSource,coreLifecycleSourceProof} from './helpers/core-lifecycle-source-inverse.mjs';
import {preGameUiExtractionSource} from './helpers/game-ui-extraction-source-inverse.mjs';
import * as epoch from './helpers/relic-query-source-inverse.mjs';
import {preInventoryResponsibilitiesSource} from './helpers/inventory-responsibilities-source-inverse.mjs';
import {preM7FinalSource} from './helpers/m7-core-final-source-inverse.mjs';
import {preWatcherExecutionSource} from './helpers/watcher-final-execution-source-inverse.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
// Exercise the unchanged N35 source epoch itself. The new three-owner outer
// epoch and single-owner extractions have their own fresh-owner,
// missing/foreign-source and behavior contracts.
const read=p=>preM7FinalSource(p,preWatcherExecutionSource(p,preInventoryResponsibilitiesSource(p,preDefectPlanSource(p,normalize(readFileSync(p,'utf8'))))));
const bytes=readFileSync('tests/helpers/relic-query-baseline-391306af.json.gz');
assert.equal(hash(bytes),'df89de0002fee32b9300489b95432ce4287c467435af804f481241ee3c3bbdf2');
const frozen=JSON.parse(gunzipSync(bytes));
const original=Object.fromEntries(Object.values(frozen.files).map(file=>[file.path,file.source]));
const runtimeNames=['abyss_actor','abyss_card_actions','abyss_colorless_cards','abyss_combat','abyss_combat_effect_cards','abyss_combat_effect_dispatch','abyss_combat_native_play','abyss_combat_queued_play','abyss_defect_engine_cards','abyss_defect_utility_cards','abyss_effects_damage','abyss_end_turn_powers','abyss_exhaust','abyss_hp_loss','abyss_inventory','abyss_original_v4_health','abyss_player_revive','abyss_potion_fairy','abyss_potion_generation','abyss_silent_tactics_cards','abyss_watcher_final_cards','abyss_watcher_flow_cards','abyss_writhing_mass'];
const runtimeArchive=readFileSync('tests/helpers/relic-lifecycle-baseline-391306af.json.gz');
assert.equal(hash(runtimeArchive),'30c35c0b2298dc33ee3227a5dfc7aa32b5e0959fe11dbe30aef17a5af1ce5067');
const runtimeBytes=gunzipSync(runtimeArchive);assert.equal(hash(runtimeBytes),'0c1593569f1b3f849a15ade6981ebb56fe194e9a6b118f12749084d73ac15476');
const runtimeCorpus=JSON.parse(runtimeBytes);assert.equal(runtimeCorpus.revision,'391306af70d9f5c6fb510223e113fcb7dcb755df');
const runtimeOld=Object.fromEntries(runtimeNames.map(name=>{const file=runtimeCorpus.files[name];assert.equal(hash(file.source),file.sha256);return[file.path,file.source];}));
const query='src/lua/abyss_relic_queries.lua',purge='src/lua/abyss_purge_candidates.lua',livingWall='src/lua/abyss_living_wall.lua',config='config/architecture.json';
const combatHooks='src/lua/abyss_relic_combat_hooks.lua',family='src/lua/abyss_relic_family_combat.lua';
const old={...original,[livingWall]:read('tests/helpers/query-living-wall-before.lua'),...runtimeOld};
const paths=[...Object.keys(old),config],owners=[...Object.keys(original),query,livingWall,purge,...Object.keys(runtimeOld),combatHooks,family,config];
const inverse=()=>{assert.deepEqual(Object.keys(epoch.relicQuerySourceProof.files),owners,'one complete thirty-five-owner relic epoch');return epoch.preRelicQuerySource;};
const publicPrior=(path,source,options)=>preCoreLifecycleSource(path,source,options);

test('complete final lifecycle epoch restores all thirty existing Lua owners and exact 391 architecture without inventing witness history',()=>{
 const prior=inverse();assert.deepEqual(Object.keys(epoch.relicQuerySourceProof.files),owners);
 for(const path of paths){
  const source=read(path),expected=path===config?prior(path,source):old[path];
  assert.notEqual(hash(source),hash(expected),'an actual changed complete source must enter the new epoch');
  assert.equal(prior(path,source),expected);assert.equal(prior(path,source.replaceAll('\n','\r\n')),expected);
  assert.equal(publicPrior(path,source),publicPrior(path,expected),'all older source guards still run');
 }
 const previous=prior(config,read(config));
 assert.equal(hash(old[livingWall]),'6216528eecca0c6e2be5db454a39547b124c3302948f8347ae6535a78328311c');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(old[livingWall])+'\0').update(old[livingWall]).digest('hex'),'5afe2f952d7fb29d201afa8b67bc361c59e4dbdf');
 assert.equal(hash(previous),'68d46e73d734f9684326b24ba040706d768349ce9a552daf52006bb900bfaabf');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),'ad1880710f0b186d3532517d8f51496622141963');
 for(const source of [JSON.stringify(JSON.parse(read(config))),JSON.stringify(JSON.parse(read(config)),null,'\t'),read(config)+'\n\t '])assert.equal(prior(config,source),previous);
 assert.equal(JSON.parse(previous).deferredImports.filter(row=>row.from==='abyss_boss_relics'&&row.to==='abyss_living_wall').length,1,'the original unique Boss deferred edge is restored');
 for(const witness of [query,purge,combatHooks,family]){
  assert.equal(Object.hasOwn(epoch.relicQuerySourceProof.files[witness],'beforeSource'),false);
  assert.equal(Object.hasOwn(epoch.relicQuerySourceProof.files[witness],'beforeSha256'),false);
  assert.equal(prior(witness,read(witness),{readSource(){assert.fail('witness-only input cannot read owners');}}),read(witness));
 }
 for(const path of ['src/lua/abyss_actor.lua','src/lua/abyss_combat.lua'])
  assert.equal(hash(old[path]),coreLifecycleSourceProof.files[path].afterSha256,'restore exact 391 identity before entering the unchanged old core proof');
 const actor='src/lua/abyss_actor.lua',host='src/lua/abyss_game_ui.lua';
 const cases=[['direct',prior,actor,35],['core',preCoreLifecycleSource,actor,144],['GameUI host',preGameUiExtractionSource,host,151],['GameUI config',preGameUiExtractionSource,config,295]];
 for(const [name,consume,path,expected]of cases){
  let reads=0;consume(path,read(path),{readSource:p=>{reads++;return read(p);}});
  assert.equal(reads,expected,'unchanged N35/k2 fresh owner contract: '+name);
 }
});

test('foreign, original, partial, duplicate and escaped-token sources retain their bytes without reading any linked owner',()=>{
 const prior=inverse();let reads=0;const options={readSource(){reads++;throw Error('must not read');}};
 const originals={...old,[config]:prior(config,read(config))};
 for(const path of paths){
  const source=read(path),variants=[originals[path],null,false,17,{},'',source.slice(1),source+source,source+(path===config?'\n-- foreign\n':'\n')];
  if(path===config){
   variants.push(source.replace('"abyss_relic_queries":','"abyss_relic_queries": "core", "abyss_relic_queries":'),source.replace('"abyss_relic_queries"','"abyss_relic_queri\\u0065s"'));
   variants.push(source.replace('"abyss_purge_candidates":','"abyss_purge_candidates": "core", "abyss_purge_candidates":'),source.replace('"abyss_purge_candidates"','"abyss_purge_candidat\\u0065s"'));
   const changed=JSON.parse(source);changed.dependencyBoundaries.reverse();variants.push(JSON.stringify(changed));
  }
  for(const input of variants)assert.equal(prior(path,input,options),input);
  assert.equal(prior('foreign/'+path,source,options),source);
 }
 assert.equal(reads,0);
});

test('each direct and common source call freshly binds all thirty-five raw owners after warm successes, failures and reader wrapping',()=>{
 const prior=inverse(),originals={...old,[config]:prior(config,read(config))};
 for(const consume of [prior,publicPrior])for(const host of paths)for(const linked of owners){
  const source=read(host),expected=consume(host,source);let mode='good',reads=[];
  const readSource=p=>{reads.push(p);if(p===linked){if(mode==='throw')throw Error('reader sentinel');if(mode==='missing')return undefined;if(mode==='null')return null;if(mode==='drift')return read(p)+'\n';if(mode==='old')return originals[p];}return read(p);};
  assert.equal(consume(host,source,{readSource}),expected);assert.deepEqual(consume===prior?reads:reads.slice(0,35),owners);
  for(mode of ['throw','missing','null','drift','old']){
   reads=[];assert.throws(()=>consume(host,source,{readSource}),/relic query linked/);assert.ok(reads.includes(linked));
  }
  mode='good';reads=[];assert.equal(consume(host,source,{readSource}),expected);assert.deepEqual(consume===prior?reads:reads.slice(0,35),owners);
  const nested=epoch.relicQueryReader(epoch.relicQueryReader(readSource));
  assert.equal(prior(host,source,{readSource:nested}),originals[host]);
  mode='drift';assert.throws(()=>prior(host,source,{readSource:nested}),/relic query linked/);
 }
 assert.throws(()=>prior(paths[0],read(paths[0]),{readSource:null}),/linked reader/);
 const actor='src/lua/abyss_actor.lua',source=read(actor);
 for(const boundary of [36,72,108]){
  let reads=0;
  assert.throws(()=>publicPrior(actor,source,{readSource:p=>read(p)+(++reads>=boundary?'\n':'')}),/linked owner/,'a same-call stateful reader must expose drift after an earlier complete owner scan');
 }
});

test('real isolated thirty-five-owner files reject warm source edits, configuration reformatting and deletion without borrowing the live tree',()=>{
 const prior=inverse(),source=Object.fromEntries(owners.map(path=>[path,read(path)]));
 const expected={...old,[config]:prior(config,source[config])};
 const cwd=process.cwd(),directory=mkdtempSync(join(tmpdir(),'relic-query-source-'));
 try{
  for(const path of owners){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source[path]);}
  process.chdir(directory);
  for(const host of paths)for(const linked of owners){
   assert.equal(prior(host,source[host]),expected[host]);
   writeFileSync(linked,source[linked]+'\n');assert.throws(()=>prior(host,source[host]),/relic query linked/);
   writeFileSync(linked,source[linked]);assert.equal(prior(host,source[host]),expected[host]);
   rmSync(linked);assert.throws(()=>prior(host,source[host]),/relic query linked/);
   writeFileSync(linked,source[linked]);assert.equal(prior(host,source[host]),expected[host]);
  }
  writeFileSync(config,JSON.stringify(JSON.parse(source[config])));
  assert.throws(()=>prior(paths[0],source[paths[0]]),/relic query linked/,'layout-equivalent inputs never excuse drift in the linked real file');
 }finally{process.chdir(cwd);rmSync(directory,{recursive:true,force:true});}
});
