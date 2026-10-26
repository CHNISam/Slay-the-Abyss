import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const builder = fileURLToPath(new URL('../scripts/build-native-candidate.mjs', import.meta.url));
const existing = { id: 1073741899, name: '_GSTS_ABYSS_SETTLEMENT', type: 20000, writable: true };
// Fake only the MCP boundary: execute the actual CLI and inspect its calls.
const sdk = `
import {appendFileSync,readFileSync} from 'node:fs';
const state=JSON.parse(readFileSync(process.env.REBUILD_SCENARIO,'utf8'));
const scripts=new Map((state.scripts??[]).map(s=>[s.name,s]));
export class Client {
 async connect() {} async close() {}
 async readResource({uri}) {return {contents:[{uri,text:'fixture'}]};}
 async callTool({name,arguments:args}) {
  appendFileSync(process.env.REBUILD_CALLS,JSON.stringify({name,args})+'\\n');
  if(name===state.failTool)return {isError:true,structuredContent:{error:{code:'FIXTURE_FAILURE',message:name}}};
  if(name===state.payloadErrorTool)return {structuredContent:{error:{code:'PAYLOAD_FAILURE',message:name}}};
  if(name===state.malformedTool)return {structuredContent:{mapPath:args.mapPath}};
  if(name==='scene_set_client_script')scripts.set(args.name,{name:args.name,file:args.name+'.lua',on:[],source:readFileSync(args.sourceFile,'utf8')});
  if(name==='scene_list_client_scripts')return {structuredContent:{mapPath:args.mapPath,scripts:[...scripts.values()]}};
  if(name==='scene_remove_client') {
   if(!state.ignoreRemoval)scripts.delete(args.script);
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
  if(name==='scene_check_client')return {structuredContent:{mapPath:args.mapPath,ok:true,errors:0,warnings:0,checked:[...scripts.keys()]}};
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
    put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js',sdk);
    put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js','export class StdioClientTransport {constructor(options) {if(options.env.MILIASTRA_ALLOW_LIVE_WRITE!=="0")throw Error("live writes enabled");}}');
    put('src/lua/abyss_ui.lua','return {}');
    put('scripts/build-lua-data.mjs',`import {writeFileSync} from 'node:fs';import {dirname,join} from 'node:path';writeFileSync(process.argv[3],'return {}');writeFileSync(join(dirname(process.argv[3]),'abyss_original_v4_data.lua'),'return {}');`);
    put('scripts/build-ui.mjs',`import {writeFileSync} from 'node:fs';import {join} from 'node:path';const out=process.argv[2];for(const name of ['abyss_map_layout','abyss_narrative','abyss_presentation','abyss_theme'])writeFileSync(join(out,name+'.lua'),'return {}');writeFileSync(join(out,'game-ui.json'),JSON.stringify({name:'SlayTheAbyss',script:'abyss_ui',controls:[]}));writeFileSync(join(out,'game-ui-templates.json'),'[]');`);
    for(const name of ['abyss_data','abyss_original_v4_data','abyss_map_layout','abyss_narrative','abyss_presentation','abyss_theme'])put('build/lua/'+name+'.lua','return {}');
    put('build/lua/game-ui.json',JSON.stringify({name:'SlayTheAbyss',script:'abyss_ui',controls:[]}));
    put('build/lua/game-ui-templates.json','[]');
    put('scenario.json',JSON.stringify(scenario));
    put('calls.jsonl',''); put('base.gil','fixture');
    const result=spawnSync(process.execPath,[builder,join(dir,'base.gil'),join(dir,'out')],{cwd:dir,encoding:'utf8',env:{...process.env,MILIASTRA_MCP_ROOT:join(dir,'tool'),REBUILD_SCENARIO:join(dir,'scenario.json'),REBUILD_CALLS:join(dir,'calls.jsonl')}});
    if(result.error)throw result.error;
    const calls=readFileSync(join(dir,'calls.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
    check(result,calls);
  } finally { rmSync(dir,{recursive:true,force:true}); }
}
const success = result => assert.equal(result.status,0,result.stderr);

test('rebuilding existing scene replaces UI, reuses actual graph id and preserves existing signals',()=>run({hasUi:true,graphs:[existing],signals:['ABYSS_WIN','ABYSS_LOSE']},(result,calls)=>{
  success(result);
  assert.equal(calls.find(c=>c.name==='scene_add_client_ui').args.replace,true);
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
  assert.equal(calls.filter(c=>c.name==='scene_list_client_scripts'&&!c.args.includeSource).length,2);
  assert.equal(calls.filter(c=>c.name==='scene_list_client_scripts'&&c.args.includeSource).length,1);
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
  assert.ok(!calls.some(c=>c.name==='write_graphs'||c.name==='scene_check_client'));
}));

test('malformed script inventory cannot be interpreted as clean',()=>run({malformedTool:'scene_list_client_scripts'},(result,calls)=>{
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/script inventory/i);
  assert.ok(!calls.some(c=>c.name==='scene_remove_client'||c.name==='write_graphs'||c.name==='scene_check_client'));
}));
