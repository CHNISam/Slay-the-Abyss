import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,mkdtempSync,rmSync,symlinkSync} from 'node:fs';
import {join,dirname,resolve,relative,isAbsolute} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {gameUiExtractionProof as proof,gameUiExtractionAddedPaths as added,preGameUiExtractionSource as project,gameUiExtractionReader,prepareGameUiExtractionModuleRetirement as prepare} from './helpers/game-ui-extraction-source-inverse.mjs';
import {preCoreLifecycleSource} from './helpers/core-lifecycle-source-inverse.mjs';
import {preRelicQuerySource} from './helpers/relic-query-source-inverse.mjs';
// Keep the existing two/four-owner contracts in their original source epochs.
const read=p=>preRelicQuerySource(p,readFileSync(p,'utf8').replaceAll('\r\n','\n'));
const host='src/lua/abyss_game_ui.lua',architecture='config/architecture.json';
const paths=Object.keys(proof.files);
const lifecycleSources=['src/lua/abyss_actor.lua','src/lua/abyss_combat.lua','src/lua/abyss_actor_power_rules.lua'];
const lifecycleHelpers=['tests/helpers/core-lifecycle-source-inverse.mjs','tests/helpers/actor-lifecycle-before.lua','tests/helpers/combat-lifecycle-before.json','tests/helpers/relic-query-source-inverse.mjs','tests/helpers/relic-query-baseline-391306af.json.gz','tests/helpers/query-living-wall-before.lua','tests/helpers/relic-lifecycle-baseline-391306af.json.gz','tests/helpers/relic-lifecycle-architecture-source-inverse.json','tests/helpers/m7-core-final-source-inverse.mjs','tests/helpers/m7-core-final-before.json.gz','tests/helpers/power-shop-source-inverse.mjs','tests/helpers/power-shop-before-2c85.json.gz'];
const lifecycleReads=4;
const originalInputs=()=>Object.fromEntries(paths.map(path=>[path,preCoreLifecycleSource(path,read(path))]));
function copy(root,path){const target=join(root,path);mkdirSync(dirname(target),{recursive:true});if(path===architecture||lifecycleSources.includes(path))writeFileSync(target,read(path));else copyFileSync(path,target);}
function isolated(t){const root=mkdtempSync(join(tmpdir(),'game-ui-source-proof-'));t.after(()=>rmSync(root,{recursive:true,force:true}));return root;}

test('one complete extraction restores immutable full Host/config and authenticates each fresh owner',()=>{
 assert.equal(proof.baseCommit,'78e4e746a7f05754f0d838999c466cd88630368c');
 assert.equal(proof.files[host].beforeSource,read('tests/fixtures/game-ui-host/old-host.lua'));
 assert.equal(proof.files[host].beforeSha256,JSON.parse(read('tests/fixtures/game-ui-host/identity.json')).sha256);
 const original=originalInputs();let originalReads=0;
 const readOriginal=p=>{originalReads++;return original[p];};
 for(const path of paths)for(const input of [original[path],original[path].replaceAll('\n','\r\n')])
  assert.equal(project(path,input,{readSource:readOriginal}),proof.files[path].beforeSource);
 assert.equal(originalReads,paths.length*paths.length*2,'the independent original Host epoch still performs exactly 98 reads');
 let reads=0;const readSource=p=>{reads++;return read(p);};
 for(const path of paths){
  const source=read(path),before=proof.files[path].beforeSource;
  assert.equal(project(path,source,{readSource}),before);
  assert.equal(project(path,source.replaceAll('\n','\r\n'),{readSource}),before);
 }
 // Original Host epoch: 98 reads. Each of its 14 validations now encounters
 // one new config (4 fresh owners), and the two config inputs add 4 each.
 assert.equal(reads,paths.length*paths.length*2+paths.length*lifecycleReads*2+lifecycleReads*2);
 for(const source of [JSON.stringify(JSON.parse(read(architecture))),JSON.stringify(JSON.parse(read(architecture)),null,'\t')]){
  const prior=reads;assert.equal(project(architecture,source,{readSource}),proof.files[architecture].beforeSource);
  assert.equal(reads-prior,paths.length+lifecycleReads*2,'layout-equivalent architecture rereads the exact outer and inner owner closures');
 }
 for(const readSource of [null,{},'invalid',()=>undefined,()=>null,()=>Buffer.from('source'),()=>{throw Error('reader sentinel');}])
  assert.throws(()=>project(host,read(host),{readSource}),/linked reader|linked owner|reader sentinel/);
 assert.ok(Object.isFrozen(proof)&&Object.isFrozen(proof.files)&&Object.isFrozen(proof.files[host]));
});

test('foreign and old epochs perform zero linked reads, including duplicate keys and escaped JSON tokens',()=>{
 let reads=0;const readSource=()=>{reads++;throw Error('must not read');};
 const source=read(host),config=read(architecture),policy=JSON.parse(config);
 const foreign=structuredClone(policy);foreign.layers.abyss_game_ui_input='core';
 const unknown=structuredClone(policy);unknown.unreviewed=true;
 const configVariants=[JSON.stringify(foreign),JSON.stringify(unknown),config.replace('"abyss_game_ui_input":','"abyss_game_ui_input": "ui", "abyss_game_ui_input":'),config.replace('"abyss_game_ui_input"','"abyss_game_ui_inp\\u0075t"')];
 for(const [path,input]of [[host,source+source],[host,source.slice(1)],[host,source+'\n'],[host,proof.files[host].beforeSource],[architecture,proof.files[architecture].beforeSource],['foreign/'+host,source],[host,null],[host,{}],...configVariants.map(s=>[architecture,s])])
  assert.equal(project(path,input,{readSource}),input);
 assert.equal(reads,0);
});

test('configuration owner names never waive complete tokens or fresh linked validation',()=>{
 const config=read(architecture),names=added.map(path=>path.split('/').at(-1).slice(0,-4));
 const oldWithNames=JSON.parse(proof.files[architecture].beforeSource);oldWithNames.note=names;
 const escapedWithNames=config.replace('"abyss_game_ui_input"','"abyss_game_ui_inp\\u0075t"').replace(/\n}\s*$/,
  ',\n  "note": '+JSON.stringify(names)+'\n}\n');
 let reads=0;const forbid=()=>{reads++;throw Error('foreign config must not read owners');};
 for(const source of [proof.files[architecture].beforeSource,JSON.stringify(oldWithNames),escapedWithNames])
  assert.equal(project(architecture,source,{readSource:forbid}),source);
 assert.equal(reads,0);
 for(const source of [config,JSON.stringify(JSON.parse(config)),JSON.stringify(JSON.parse(config),null,'\t')]){
  let current=read;
  const readSource=path=>{reads++;return current(path);};
  assert.equal(project(architecture,source,{readSource}),proof.files[architecture].beforeSource);
  current=path=>read(path)+(path===added.at(-1)?'\n-- fresh owner drift\n':'');
  assert.throws(()=>project(architecture,source,{readSource}),/linked owner/);
 }
 assert.equal(reads,(paths.length+lifecycleReads*2)*6,'exact and layout-equivalent config admission rereads all owners each time');
});

test('nested linked readers keep fresh raw identities across composed historical boundaries',()=>{
 const original=originalInputs();let originalReads=0;
 const originalReader=gameUiExtractionReader(p=>{originalReads++;return original[p];});
 for(let i=0;i<2;i++){
  assert.equal(project(host,original[host],{readSource:originalReader}),proof.files[host].beforeSource);
  assert.equal(originalReader(host),proof.files[host].beforeSource);
 }
 assert.equal(originalReads,paths.length*4+2,'the independent original nested-reader epoch still performs exactly 30 reads');
 let reads=0;const raw=p=>{reads++;return read(p);};
 const reader=gameUiExtractionReader(raw);
 assert.equal(gameUiExtractionReader(reader),reader);
 for(let i=0;i<2;i++){
  assert.equal(project(host,read(host),{readSource:reader}),proof.files[host].beforeSource);
  assert.equal(reader(host),proof.files[host].beforeSource);
 }
 // Original nested-reader epoch: 30 reads; four linked config projections
 // each add exactly the four final lifecycle owners, giving 46.
 assert.equal(reads,paths.length*4+2+lifecycleReads*4);
});

test('actual current Host reaches every direct and transitive consumer with frozen historical results',async()=>{
 const consumers=[
  ['compendium-source-inverse','preCompendiumSource'],
  ['round2-ui-source-inverse','preRound2UiSource'],
  ['relic-art-composition','preRelicArtCompositionSource','relic'],
  ['relic-art-composition','preRelicArtCompositionSource','art'],
  ['relic-round2-composition','preRelicRound2CompositionSource','relic'],
  ['relic-round2-composition','preRelicRound2CompositionSource','round2'],
  ['deck-browse-source-inverse','preDeckBrowseSource'],
  ['deck-delivery-source-composition','preDeckDeliverySource','delivery'],
  ['deck-delivery-source-composition','preDeckDeliverySource','deck'],
  ['delivery-source-composition','preAcceptedDevelopSource'],
  ['pr372-integration-source','preIntegrationSource'],
  ['multi-monster-art-source-inverse','preMultiMonsterArtSource'],
  ['native-monster-art-source-inverse','preNativeMonsterArtSource'],
  ['art-perf-source-composition','projectArtPerfSource','art'],
  ['art-perf-source-composition','projectArtPerfSource','perf'],
  ['battle-life-source-inverse','preBattleLifeSource'],
 ];
 for(const [module,name,target]of consumers){
  const fn=(await import('./helpers/'+module+'.mjs'))[name];
  for(const path of [host,architecture]){
   const current=read(path),old=proof.files[path].beforeSource;
   const expected=fn(path,old,target),actual=fn(path,current,target);
   assert.equal(actual,expected,module+' '+target+' '+path);
   assert.notEqual(actual,current,'the current extraction must be consumed: '+module+' '+path);
  }
 }
});

test('injected readers at shared consumer seams never fall back to live owners',async()=>{
 const {preDeckDeliverySource}=await import('./helpers/deck-delivery-source-composition.mjs');
 const {preIntegrationSource}=await import('./helpers/pr372-integration-source.mjs');
 const {preRound2UiSource}=await import('./helpers/round2-ui-source-inverse.mjs');
 const consumers=[
  readSource=>preDeckDeliverySource(host,read(host),'delivery',{readSource}),
  readSource=>preIntegrationSource(host,read(host),'base',{readSource}),
  readSource=>preRound2UiSource(host,read(host),{readSource}),
 ];
 for(const consume of consumers){
  assert.equal(typeof consume(read),'string');
  for(const owner of paths){
   assert.throws(()=>consume(path=>path===owner?read(path)+'\n-- injected drift\n':read(path)),/linked owner/);
   assert.throws(()=>consume(path=>{if(path===owner)throw Error('injected missing '+owner);return read(path);}),/injected missing/);
  }
  for(const invalid of [null,{},'invalid'])assert.throws(()=>consume(invalid),/linked reader/);
 }
});

test('actual detached filesystem owners reject warm drift and deletion separately for every module',async t=>{
 const root=isolated(t);
 for(const path of [...paths,...lifecycleSources,...lifecycleHelpers,'tests/helpers/game-ui-extraction-source-inverse.mjs','tests/helpers/game-ui-extraction-source-layer.json'])copy(root,path);
 const {preGameUiExtractionSource:detached}=await import(pathToFileURL(join(root,'tests/helpers/game-ui-extraction-source-inverse.mjs')));
 for(const input of [host,architecture])for(const owner of paths){
  const source=read(input),file=join(root,owner),original=read(owner),expected=detached(input,source);
  writeFileSync(file,original+'\n-- warm linked drift\n');
  assert.throws(()=>detached(input,source),/linked owner/);
  writeFileSync(file,original);assert.equal(detached(input,source),expected);
  rmSync(file);assert.throws(()=>detached(input,source),/ENOENT/);
  writeFileSync(file,original);assert.equal(detached(input,source),expected);
 }
});

test('retirement verifies the full isolated destination before deleting, and revalidates deferred cleanup',t=>{
 const root=isolated(t);for(const path of added)copy(root,path);
 const sourceRoot=process.cwd();
 assert.throws(()=>prepare(sourceRoot,{sourceRoot}),/isolated historical/);
 const last=added.at(-1),file=join(root,last),original=read(last);
 writeFileSync(file,original+'\n-- foreign\n');assert.throws(()=>prepare(root,{sourceRoot}),/retirement module/);
 for(const path of added)assert.doesNotThrow(()=>readFileSync(join(root,path)));
 writeFileSync(file,original);const retire=prepare(root,{sourceRoot});
 writeFileSync(file,original+'\n-- changed after prepare\n');assert.throws(retire,/retirement module/);
 for(const path of added)assert.doesNotThrow(()=>readFileSync(join(root,path)));
 writeFileSync(file,original);retire();for(const path of added)assert.throws(()=>readFileSync(join(root,path)),/ENOENT/);
});

test('retirement rejects a destination or nested owner junction aliasing the live source',t=>{
 const root=isolated(t),alias=join(root,'live');
 symlinkSync(process.cwd(),alias,'junction');
 assert.throws(()=>prepare(alias,{sourceRoot:process.cwd()}),/isolated historical/);
 const destination=join(root,'destination');mkdirSync(join(destination,'src'),{recursive:true});
 symlinkSync(join(process.cwd(),'src/lua'),join(destination,'src/lua'),'junction');
 assert.throws(()=>prepare(destination,{sourceRoot:process.cwd()}),/aliases source/);
});

test('retirement accepts real repository-local historical copies and preserves every live owner',t=>{
 const build=resolve('build');mkdirSync(build,{recursive:true});
 const root=mkdtempSync(join(build,'history-destination-test-'));
 t.after(()=>{const rel=relative(build,root);assert(rel&&!isAbsolute(rel)&&!rel.startsWith('..'));rmSync(root,{recursive:true,force:true});});
 const before=new Map(added.map(path=>[path,readFileSync(path)]));
 for(const path of added)copy(root,path);
 writeFileSync(join(root,'keep.txt'),'unrelated historical owner');
 const retire=prepare(root);
 assert(added.every(path=>readFileSync(join(root,path)).equals(before.get(path))),'preparation is read-only');
 retire();for(const path of added)assert.throws(()=>readFileSync(join(root,path)),/ENOENT/);
 assert.equal(readFileSync(join(root,'keep.txt'),'utf8'),'unrelated historical owner');
 for(const path of added)assert(readFileSync(path).equals(before.get(path)),`live owner unchanged: ${path}`);
});

test('retirement rejects live Lua directories and source ancestors before any deletion',()=>{
 const sourceRoot=process.cwd(),before=new Map(added.map(path=>[path,readFileSync(path)]));
 for(const directory of [sourceRoot,dirname(sourceRoot),join(sourceRoot,'src'),join(sourceRoot,'src/lua')])
  assert.throws(()=>prepare(directory,{sourceRoot}),/isolated historical/);
 for(const path of added)assert(readFileSync(path).equals(before.get(path)),`protected live owner unchanged: ${path}`);
});

test('repository-local cleanup rejects nested symlink escapes and revalidates all targets before deletion',t=>{
 const build=resolve('build');mkdirSync(build,{recursive:true});
 const root=mkdtempSync(join(build,'history-destination-test-'));
 t.after(()=>{const rel=relative(build,root);assert(rel&&!isAbsolute(rel)&&!rel.startsWith('..'));rmSync(root,{recursive:true,force:true});});
 const live=new Map(added.map(path=>[path,readFileSync(path)]));
 const escaped=join(root,'escaped');mkdirSync(join(escaped,'src'),{recursive:true});
 symlinkSync(resolve('src/lua'),join(escaped,'src/lua'),'junction');
 assert.throws(()=>prepare(escaped),/aliases source/);
 const destination=join(root,'copy');for(const path of added)copy(destination,path);
 const retire=prepare(destination),last=added.at(-1),file=join(destination,last);
 writeFileSync(file,read(last)+'\n-- late destination drift\n');assert.throws(retire,/retirement module/);
 for(const path of added.slice(0,-1))assert(readFileSync(join(destination,path)).equals(live.get(path)),'no earlier deletion before the last owner is validated');
 // Directory junctions exercise the same escape on Windows without requiring
 // developer-mode privileges to create individual file symbolic links.
 rmSync(join(destination,'src/lua'),{recursive:true});symlinkSync(resolve('src/lua'),join(destination,'src/lua'),'junction');
 assert.throws(retire,/aliases source/);
 rmSync(destination,{recursive:true});symlinkSync(process.cwd(),destination,'junction');
 assert.throws(retire,/destination changed after preparation/);
 for(const path of added)assert(readFileSync(path).equals(live.get(path)),`symlink escape preserved live owner: ${path}`);
});

test('real filesystem traces distinguish foreign/old inputs from fresh equivalent and warm owner reads',t=>{
 const root=isolated(t),reads={},opens={};
 for(const mode of ['foreign','old','equivalent','warm-drift','warm-missing']){
  const directory=join(root,mode);mkdirSync(directory);
  for(const path of [...paths,...lifecycleSources,...lifecycleHelpers,'tests/helpers/game-ui-extraction-source-inverse.mjs','tests/helpers/game-ui-extraction-source-layer.json','tests/helpers/game-ui-extraction-read-probe.mjs'])copy(directory,path);
  const trace=join(root,mode+'.trace.json');
  const result=spawnSync(process.execPath,['--trace-event-file-pattern='+trace,'tests/helpers/game-ui-extraction-read-probe.mjs',mode],{cwd:directory,encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
  const events=JSON.parse(readFileSync(trace,'utf8')).traceEvents.filter(event=>event.ph==='B');
  reads[mode]=events.filter(event=>event.name==='fs.sync.read').length;
  opens[mode]=events.filter(event=>event.name==='fs.sync.open').length;
  if(process.env.ABYSS_SOURCE_EVIDENCE_DIR){
   const evidence=process.env.ABYSS_SOURCE_EVIDENCE_DIR;mkdirSync(evidence,{recursive:true});
   copyFileSync(trace,join(evidence,'game-ui-'+mode+'.trace.json'));
   writeFileSync(join(evidence,'game-ui-'+mode+'.stdout.log'),result.stdout);writeFileSync(join(evidence,'game-ui-'+mode+'.stderr.log'),result.stderr);
  }
 }
 assert.equal(reads.foreign,0);assert.equal(reads.old,0);
 assert.equal(reads.equivalent,paths.length*2+lifecycleReads*4);
 assert.equal(reads['warm-drift'],paths.length+lifecycleReads*2);assert.equal(reads['warm-missing'],paths.length-1+lifecycleReads*2);
 assert.deepEqual(opens,{foreign:0,old:0,equivalent:paths.length*2+lifecycleReads*4,'warm-drift':paths.length+lifecycleReads*2,'warm-missing':paths.length+lifecycleReads*2});
 process.stdout.write('GAME_UI_EXTRACTION_FS_READS '+JSON.stringify({reads,opens})+'\n');
});
