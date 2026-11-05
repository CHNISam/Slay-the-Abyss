import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,mkdtempSync,rmSync,symlinkSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {gameUiExtractionProof as proof,gameUiExtractionAddedPaths as added,preGameUiExtractionSource as project,gameUiExtractionReader,prepareGameUiExtractionModuleRetirement as prepare} from './helpers/game-ui-extraction-source-inverse.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const host='src/lua/abyss_game_ui.lua',architecture='config/architecture.json';
const paths=Object.keys(proof.files);
function copy(root,path){const target=join(root,path);mkdirSync(dirname(target),{recursive:true});copyFileSync(path,target);}
function isolated(t){const root=mkdtempSync(join(tmpdir(),'game-ui-source-proof-'));t.after(()=>rmSync(root,{recursive:true,force:true}));return root;}

test('one complete extraction restores immutable full Host/config and authenticates each fresh owner',()=>{
 assert.equal(proof.baseCommit,'78e4e746a7f05754f0d838999c466cd88630368c');
 assert.equal(proof.files[host].beforeSource,read('tests/fixtures/game-ui-host/old-host.lua'));
 assert.equal(proof.files[host].beforeSha256,JSON.parse(read('tests/fixtures/game-ui-host/identity.json')).sha256);
 let reads=0;const readSource=p=>{reads++;return read(p);};
 for(const path of paths){
  const source=read(path),before=proof.files[path].beforeSource;
  assert.equal(project(path,source,{readSource}),before);
  assert.equal(project(path,source.replaceAll('\n','\r\n'),{readSource}),before);
 }
 assert.equal(reads,paths.length*paths.length*2);
 for(const source of [JSON.stringify(JSON.parse(read(architecture))),JSON.stringify(JSON.parse(read(architecture)),null,'\t')]){
  const prior=reads;assert.equal(project(architecture,source,{readSource}),proof.files[architecture].beforeSource);
  assert.equal(reads-prior,paths.length,'layout-equivalent architecture still rereads every owner');
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

test('nested linked readers keep fresh raw identities across composed historical boundaries',()=>{
 let reads=0;const raw=p=>{reads++;return read(p);};
 const reader=gameUiExtractionReader(raw);
 assert.equal(gameUiExtractionReader(reader),reader);
 for(let i=0;i<2;i++){
  assert.equal(project(host,read(host),{readSource:reader}),proof.files[host].beforeSource);
  assert.equal(reader(host),proof.files[host].beforeSource);
 }
 assert.equal(reads,paths.length*4+2);
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
 for(const path of [...paths,'tests/helpers/game-ui-extraction-source-inverse.mjs','tests/helpers/game-ui-extraction-source-layer.json'])copy(root,path);
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

test('real filesystem traces distinguish foreign/old inputs from fresh equivalent and warm owner reads',t=>{
 const root=isolated(t),reads={},opens={};
 for(const mode of ['foreign','old','equivalent','warm-drift','warm-missing']){
  const directory=join(root,mode);mkdirSync(directory);
  for(const path of [...paths,'tests/helpers/game-ui-extraction-source-inverse.mjs','tests/helpers/game-ui-extraction-source-layer.json','tests/helpers/game-ui-extraction-read-probe.mjs'])copy(directory,path);
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
 assert.equal(reads.equivalent,paths.length*2);
 assert.equal(reads['warm-drift'],paths.length);assert.equal(reads['warm-missing'],paths.length-1);
 assert.deepEqual(opens,{foreign:0,old:0,equivalent:paths.length*2,'warm-drift':paths.length,'warm-missing':paths.length});
 process.stdout.write('GAME_UI_EXTRACTION_FS_READS '+JSON.stringify({reads,opens})+'\n');
});
