import {artFeatureModule,artFeaturesSource} from '../scripts/art-features.mjs';
import {generatedRuntimeModules} from '../scripts/build-native-candidate.mjs';
import {monsterActorTemplate} from '../scripts/monster-art.mjs';
import {enemyPowerTemplate} from '../scripts/ui-layout.mjs';
import {readyArtTemplates,readyArtGroupTemplate} from '../scripts/art/ready-card-runtime.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import {fixtureMapBytes,installNativeToolchainFixture,readFixtureScripts} from './helpers/native-toolchain-fixture.mjs';
import {sha256} from '../scripts/evidence-files.mjs';

const builder = fileURLToPath(new URL('../scripts/build-native-candidate.mjs', import.meta.url));
const existing = { id: 1073741899, name: '_GSTS_ABYSS_SETTLEMENT', type: 20000, writable: true };
const uiModules = Object.keys(generatedRuntimeModules).filter(name=>generatedRuntimeModules[name]==='scripts/build-ui.mjs');
// Rebuild/ownership fixtures exercise the ordinary default-off candidate.
// Artwork binding and template contracts have separate opt-in integration tests.
const templates = [readyArtTemplates().find(template=>template.name===readyArtGroupTemplate),monsterActorTemplate(null),enemyPowerTemplate()];
const generatedSource = name => name === artFeatureModule ? artFeaturesSource({})
  : name === 'abyss_monster_art_data' ? '-- Generated from the bounded native monster registry.\nreturn {}\n' : 'return {}';
// Fake only the MCP boundary: execute the actual CLI and inspect its calls.
const sdk = `
import {appendFileSync,readFileSync} from 'node:fs';
import {readScripts,writeScripts} from __NATIVE_FIXTURE_STORE__;
const state=JSON.parse(readFileSync(process.env.REBUILD_SCENARIO,'utf8'));
export class Client {
 async connect() {} async close() {}
 async readResource({uri}) {return {contents:[{uri,text:'fixture'}]};}
 async callTool({name,arguments:args}) {
  appendFileSync(process.env.REBUILD_CALLS,JSON.stringify({name,args})+'\\n');
  if(name===state.failTool)return {isError:true,structuredContent:{error:{code:'FIXTURE_FAILURE',message:name}}};
  if(name===state.payloadErrorTool)return {structuredContent:{error:{code:'PAYLOAD_FAILURE',message:name}}};
  if(name===state.malformedTool)return {structuredContent:{mapPath:args.mapPath}};
  if(name==='scene_add_client_template'){
   const indices={AbyssReadyCardGroup:1073741848,AbyssMonsterActor:1073741849,AbyssMonsterPower:1073741850};
   if(!Object.hasOwn(indices,args.template.name))throw Error('Unregistered native template '+args.template.name);
   return {structuredContent:{mapPath:args.mapPath,templateIndex:indices[args.template.name]}};
  }
  if(name==='scene_set_client_script')throw Error('Rebuild must exercise real batch writer');
  if(name==='scene_list_client_scripts')throw Error('Rebuild must exercise local complete inventory reader');
  if(name==='scene_remove_client') {
   if(!state.ignoreRemoval)writeScripts(args.mapPath,readScripts(args.mapPath).filter(s=>s.name!==args.script));
   return {structuredContent:{mapPath:args.mapPath,removed:{script:args.script,scriptId:1073741800}}};
  }
  if(name==='inspect_map')return {structuredContent:{graphs:state.graphs??[]}};
  if(name==='scene_list_signals')return {structuredContent:{mapPath:args.mapPath,signals:state.signals??[]}};
  if(name==='scene_add_client_ui' && state.hasUi && !args.replace)return {isError:true,structuredContent:{error:{code:'DUPLICATE_UI'}}};
  if(name==='scene_add_signal' && (state.signals??[]).includes(args.name))return {isError:true,structuredContent:{error:{code:'DUPLICATE_SIGNAL_NAME'}}};
  if(name==='scene_add_graph') {
   if((state.graphs??[]).some(g=>g.name==='_GSTS_'+args.name))return {isError:true,structuredContent:{error:{code:'DUPLICATE_GRAPH_NAME'}}};
   return {structuredContent:{mapPath:args.mapPath,graphId:1073741900,name:'_GSTS_ABYSS_SETTLEMENT'}};
  }
  if(name==='write_graphs')return {structuredContent:{mapPath:args.mapPath,written:[{graphId:args.graphs[0].graphId}]}};
  if(name==='scene_check_client'){
   const scripts=readScripts(args.mapPath);
   if(state.corruptFinalModule)writeScripts(args.mapPath,scripts.map(s=>s.name===state.corruptFinalModule?{...s,source:s.source+' -- stale'}:s));
   return {structuredContent:{mapPath:args.mapPath,ok:true,errors:0,warnings:0,checked:scripts.map(s=>s.name)}};
  }
  return {structuredContent:{mapPath:args.mapPath}};
 }
}
`;
function run(scenario, check) {
  // Keep the real CLI's Git provenance lookup inside the repository. All MCP
  // and generation boundaries are fixture-only; receipt/readback checks run.
  mkdirSync('build',{recursive:true});
  const dir = mkdtempSync(join(process.cwd(), 'build', 'abyss-rebuild-'));
  const put = (file, content) => { const target=join(dir,file);mkdirSync(join(target,'..'),{recursive:true});writeFileSync(target,content); };
  try {
    put('tool/package.json','{"type":"module","version":"fixture"}');
    put('tool/src/debug-log.mjs','export function inspectDebugLog(){throw Error("unexpected playtest decode");}');
    installNativeToolchainFixture(join(dir,'tool'),sdk);
    put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js','export class StdioClientTransport {constructor(options) {if(options.env.MILIASTRA_ALLOW_LIVE_WRITE!=="0")throw Error("live writes enabled");}}');
    put('src/lua/abyss_ui.lua','return {}');
    put('data/cards.json',readFileSync('data/cards.json'));
    put('scripts/build-lua-data.mjs',`import {writeFileSync} from 'node:fs';import {dirname,join} from 'node:path';writeFileSync(process.argv[3],'return {}');writeFileSync(join(dirname(process.argv[3]),'abyss_original_v4_data.lua'),'return {}');`);
    put('scripts/build-ui.mjs',`import {writeFileSync} from 'node:fs';import {join} from 'node:path';const out=process.argv[2];for(const [name,source] of ${JSON.stringify(uiModules.map(name=>[name,generatedSource(name)]))})writeFileSync(join(out,name+'.lua'),source);writeFileSync(join(out,'game-ui.json'),JSON.stringify({name:'SlayTheAbyss',script:'abyss_ui',controls:[]}));writeFileSync(join(out,'game-ui-templates.json'),${JSON.stringify(JSON.stringify(templates))});`);
    for(const name of Object.keys(generatedRuntimeModules))put('build/lua/'+name+'.lua',generatedSource(name));
    put('build/lua/game-ui.json',JSON.stringify({name:'SlayTheAbyss',script:'abyss_ui',controls:[]}));
    put('build/lua/game-ui-templates.json',JSON.stringify(templates));
    put('scenario.json',JSON.stringify(scenario));
    put('calls.jsonl',''); put('base.gil',fixtureMapBytes(scenario.malformedTool==='scene_list_client_scripts'?[{file:'malformed.lua',source:'return {}'}]:scenario.scripts??[]));
    const result=spawnSync(process.execPath,[builder,join(dir,'base.gil'),join(dir,'out')],{cwd:dir,encoding:'utf8',env:{...process.env,MILIASTRA_MCP_ROOT:join(dir,'tool'),REBUILD_SCENARIO:join(dir,'scenario.json'),REBUILD_CALLS:join(dir,'calls.jsonl')}});
    if(result.error)throw result.error;
    const calls=readFileSync(join(dir,'calls.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
    check(result,calls);
    if(result.status===0){
     const receipt=JSON.parse(readFileSync(result.stdout.match(/Candidate receipt: (.+)/)[1],'utf8'));
     const actual=readFixtureScripts(receipt.mapPath);
     assert.equal(receipt.monsterActors.templateIndex,1073741849);
     assert.equal(receipt.monsterActors.containerTemplateIndex,1073741848);
     assert.equal(receipt.monsterActors.powerTemplateIndex,1073741850);
     assert.deepEqual(actual.map(s=>s.name).sort(),Object.keys(receipt.moduleDigests).sort(),'final inventory must be read from the batch-written map');
     for(const row of actual)assert.equal(sha256(row.source),receipt.moduleDigests[row.name]);
     assert(calls.some(c=>c.name==='native_batch_script'),'actual production batch writer must construct records');
     assert(!calls.some(c=>c.name==='scene_set_client_script'),'legacy per-module setter must not hide missing batch support');
    }
  } finally { rmSync(dir,{recursive:true,force:true}); }
}
const success = result => assert.equal(result.status,0,result.stderr);

test('rebuilding existing scene replaces UI, reuses actual graph id and preserves existing signals',()=>run({hasUi:true,graphs:[existing],signals:['ABYSS_WIN','ABYSS_LOSE']},(result,calls)=>{
  success(result);
  assert.equal(calls.find(c=>c.name==='scene_add_client_ui').args.replace,true);
  assert.deepEqual(calls.filter(c=>c.name==='scene_add_client_template').map(c=>c.args.template.name).sort(),
    ['AbyssMonsterActor','AbyssMonsterPower','AbyssReadyCardGroup'],
    'default-off keeps required actor/power/group templates and excludes all optional image artwork');
  const flags=calls.find(c=>c.name==='native_batch_script'&&c.args.name===artFeatureModule);
  assert(flags,'canonical default-off configuration must reach the real candidate payload');
  assert.equal(flags.args.source,artFeaturesSource({}));
  assert.equal(calls.filter(c=>c.name==='scene_add_signal'||c.name==='scene_add_graph').length,0);
  const written=calls.find(c=>c.name==='write_graphs').args.graphs[0];
  assert.equal(written.graphId,existing.id);
  assert.match(written.code,new RegExp(String(existing.id)));
}));

test('empty base creates both signals and one graph using the returned id',()=>run({},(result,calls)=>{
  success(result);
  assert.ok(calls.some(c=>c.name==='inspect_map'),'must inspect actual graph ids');
  assert.ok(calls.some(c=>c.name==='scene_list_signals'),'must inspect existing signals');
  assert.deepEqual(calls.filter(c=>c.name==='scene_add_signal').map(c=>c.args.name),['ABYSS_WIN','ABYSS_LOSE']);
  assert.equal(calls.filter(c=>c.name==='scene_add_graph').length,1);
  assert.equal(calls.find(c=>c.name==='write_graphs').args.graphs[0].graphId,1073741900);
}));

test('partially configured scene adds only its missing signal and retains unrelated graph',()=>run({graphs:[existing,{id:1073741901,name:'OtherGraph',type:20000}],signals:['ABYSS_WIN']},(result,calls)=>{
  success(result);
  assert.deepEqual(calls.filter(c=>c.name==='scene_add_signal').map(c=>c.args.name),['ABYSS_LOSE']);
  assert.equal(calls.filter(c=>c.name==='scene_add_graph').length,0);
}));

for(const failTool of ['inspect_map','scene_list_signals','scene_add_signal','scene_add_graph'])test(`${failTool} failure is not swallowed or certified`,()=>run({failTool},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/FIXTURE_FAILURE/);
  assert.ok(!calls.some(c=>c.name==='write_graphs'||c.name==='scene_check_client'));
}));

for(const graphs of [[{...existing,type:20001}],[{...existing,id:0}],[{...existing,writable:false}],[existing,{...existing,id:1073741902}]])test('ambiguous or incompatible existing settlement graph is refused',()=>run({graphs},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/settlement graph/i);
  assert.ok(!calls.some(c=>c.name==='write_graphs'));
}));

for(const malformedTool of ['inspect_map','scene_list_signals'])test(`${malformedTool} malformed inventory does not mean empty inventory`,()=>run({malformedTool},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/Cannot read settlement graph and signal inventory/);
  assert.ok(!calls.some(c=>c.name==='scene_add_graph'||c.name==='scene_add_signal'||c.name==='write_graphs'));
}));

for(const payloadErrorTool of ['scene_add_signal','scene_add_client_ui'])test(`${payloadErrorTool} explicit error payload without isError is still fatal`,()=>run({payloadErrorTool},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/PAYLOAD_FAILURE/);
  assert.ok(!calls.some(c=>c.name==='write_graphs'||c.name==='scene_check_client'));
}));

const staleScripts=['abyss_red_slaver_ai','abyss_sentry_ai'].map(name=>({name,file:name+'.lua',on:[]}));
test('rebuild removes only stale owned modules after replacing their old UI and verifies exact final inventory',()=>run({scripts:staleScripts},(result,calls)=>{
  success(result);
  assert.deepEqual(calls.filter(c=>c.name==='scene_remove_client').map(c=>c.args.script),staleScripts.map(s=>s.name));
  assert.ok(calls.findIndex(c=>c.name==='scene_add_client_ui')<calls.findIndex(c=>c.name==='scene_remove_client'));
  assert.equal(calls.filter(c=>c.name==='scene_list_client_scripts').length,0,'inventories use the local embedded reader, checked against the actual final map above');
  assert.ok(calls.filter(c=>c.name==='scene_remove_client').every(c=>!('evenIfUsed' in c.args)&&!('ui' in c.args)&&!('template' in c.args)));
}));

for(const foreign of [{name:'OtherProject',file:'OtherProject.lua',on:[]},{name:'abyss_custom',file:'foreign.lua',on:[]}])test('unknown script ownership refuses dirty base before removing any modules',()=>run({scripts:[...staleScripts,foreign]},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/unknown.*script.*clean base/i);
  assert.equal(calls.filter(c=>c.name==='scene_remove_client').length,0);
  assert.ok(!calls.some(c=>c.name==='write_graphs'||c.name==='scene_check_client'));
}));

for(const scenario of [{failTool:'scene_remove_client'},{payloadErrorTool:'scene_remove_client'},{ignoreRemoval:true}])test('stale script removal refusal or no-op cannot produce an accepted candidate',()=>run({scripts:staleScripts,...scenario},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.ok(calls.some(c=>c.name==='scene_remove_client'),'must reach the intended stale-removal failure, not fail an unrelated preflight');
  assert.match(result.stderr,scenario.failTool?/FIXTURE_FAILURE/:scenario.payloadErrorTool?/PAYLOAD_FAILURE/:/Final client script inventory differs/);
  assert.ok(!calls.some(c=>c.name==='write_graphs'||c.name==='scene_check_client'));
}));

test('malformed script inventory cannot be interpreted as clean',()=>run({malformedTool:'scene_list_client_scripts'},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/script inventory/i);
  assert.ok(!calls.some(c=>c.name==='scene_remove_client'||c.name==='write_graphs'||c.name==='scene_check_client'));
}));

test('final complete source readback refuses corruption after the static check',()=>run({corruptFinalModule:'abyss_ui'},(result,calls)=>{
 assert.notEqual(result.status,0);assert.match(result.stderr,/Candidate content digest mismatch: abyss_ui/);
 assert(calls.some(c=>c.name==='scene_check_client'));
}));
