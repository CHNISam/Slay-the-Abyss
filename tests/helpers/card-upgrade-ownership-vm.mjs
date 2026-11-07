import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {readFileSync,readdirSync,mkdirSync,writeFileSync,appendFileSync,mkdtempSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
const archive=readFileSync(new URL('./colorless-catalog-before-2ad07111.json.gz',import.meta.url));
assert.equal(createHash('sha256').update(archive).digest('hex'),'88c0ab46a951aacc45a2cf8e4a2d2c7a6ac0b5ebc153dcdf87ac600ad6ee8a95');
const corpusBytes=gunzipSync(archive);
assert.equal(createHash('sha256').update(corpusBytes).digest('hex'),'4f9d7725cf432227aa74c1bd616f0b449223a0f4b4c53a52cf6cfc5617f461cf');
export const cardUpgradeBefore=JSON.parse(corpusBytes);
assert.equal(cardUpgradeBefore.revision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
assert.equal(cardUpgradeBefore.schemaVersion,1);assert.equal(cardUpgradeBefore.normalization,'LF');
for(const [name,file]of Object.entries(cardUpgradeBefore.files)){
 assert.equal(file.path,'src/lua/'+name+'.lua');assert.equal(file.source.replaceAll('\r\n','\n'),file.source);
 assert.equal(createHash('sha256').update(file.source).digest('hex'),file.sha256);
 assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(file.source)}\0`).update(file.source).digest('hex'),file.gitBlob);
 Object.freeze(file);
}
Object.freeze(cardUpgradeBefore.files);Object.freeze(cardUpgradeBefore);
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {generatedRuntimeModules} from '../../scripts/build-native-candidate.mjs';
const require=createRequire(import.meta.url),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const hash=value=>createHash('sha256').update(value).digest('hex');
// Only exact, observed diagnostic pairs from unchanged operations are allowed.
// Raw values are separately retained. Any other location, text or case is left
// untouched, including caller errors that happen to resemble these messages.
export const cardUpgradeErrorLocations=[
 {labels:['false upgrade'],beforeFile:'abyss_combat',beforeLine:553,afterLine:77,
  statement:"elseif def.upgrade.cost~=nil and (instance.costOverride~=nil or instance.costForTurn~=nil) then",
  suffix:"attempt to index a boolean value (field 'upgrade')"},
 {labels:['invalid Blood combat cost','invalid Blood turn cost'],beforeFile:'abyss_warrior_status_cards',beforeLine:202,afterLine:37,
  statement:"assert(integer(base) and integer(turn),'invalid Blood for Blood cost metadata');return base,turn",
  suffix:'invalid Blood for Blood cost metadata'},
 {labels:['invalid upgrade count'],beforeFile:'abyss_combat',beforeLine:561,afterLine:80,
  statement:'instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1',
  suffix:'attempt to perform arithmetic on a string value'},
 {labels:['already upgraded Blood hook'],beforeFile:'abyss_warrior_status_cards',beforeLine:235,afterLine:45,
  statement:"assert(c.cardId=='blood_for_blood' and not c.upgraded,'invalid Blood for Blood upgrade')",
  suffix:'invalid Blood for Blood upgrade'},
 {labels:['unknown base definition'],beforeFile:'abyss_combat',beforeLine:417,afterLine:9,
  statement:'local def=assert(state.catalog.cards[instance.cardId])',suffix:'assertion failed!'},
 ...['nil','false'].flatMap(kind=>[
  {labels:['validator '+kind],beforeFile:'abyss_combat',beforeLine:542,afterLine:53,
   statement:"return M.validSearingBlowCopy(instance) and d and d.type~='status' and d.type~='curse' and d.upgrade~=nil and (not instance.upgraded or d.repeatable==true)",field:'validSearingBlowCopy'},
  {labels:['eligibility '+kind],beforeFile:'abyss_combat',beforeLine:545,afterLine:73,
   statement:'if not M.canUpgrade(state,instance) then return false end',field:'canUpgrade'},
  {labels:['cost '+kind],beforeFile:'abyss_combat',beforeLine:554,afterLine:64,
   statement:'local before=M.combatBaseCost(state,instance)',field:'combatBaseCost'},
  {labels:['Blood hook '+kind],beforeFile:'abyss_combat',beforeLine:550,afterLine:58,
   statement:"require('abyss_warrior_status_cards').onUpgrade(state,instance)",afterStatement:'M.onUpgrade(state,instance)',field:'onUpgrade'},
 ].map(row=>({...row,suffix:`attempt to call a ${kind==='false'?'boolean':'nil'} value (field '${row.field}')`}))),
].map(row=>({...row,before:`src/lua/${row.beforeFile}.lua:${row.beforeLine}: ${row.suffix}`,
 after:`src/lua/abyss_card_upgrade.lua:${row.afterLine}: ${row.suffix}`}));
export function normalizeCardUpgradeError(label,raw){
 return cardUpgradeErrorLocations.find(row=>row.labels.includes(label)&&row.after===raw)?.before??raw;
}
export function cardUpgradeVm(variant,fixture,{prelude='',mutation,traceFile}={}){
 assert(['before','after'].includes(variant));
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const graphs=[],logs=[],diagnostics=[],definitions=new Set();let bytes=0,hasObjectFields=false;
 assert(traceFile,'a per-process graph sink is required');writeFileSync(traceFile,'');
 installLuaGraphObserver(L,'CARD_UPGRADE_GRAPH',(label,serialized)=>{
  const graph=JSON.parse(serialized);assert(graph.root&&Array.isArray(graph.definitions),'complete graph structure');
  for(const definition of graph.definitions){
   assert.equal(definition.length,4);definitions.add(definition[1]);
   if(definition[0]==='table'&&definition[2].length>0)hasObjectFields=true;
  }
  const verify=value=>{
   assert(Array.isArray(value));
   if(['table','function','userdata','thread'].includes(value[0]))assert(definitions.has(value[1]),'every graph reference resolves to a complete definition');
  };
  verify(graph.root);
  for(const definition of graph.definitions){
   for(const [key,value]of definition[2]){verify(key);verify(value);}
   if(definition[3])verify(definition[3]);
  }
  bytes+=Buffer.byteLength(serialized);graphs.push({label,sha256:hash(serialized)});
  appendFileSync(traceFile,JSON.stringify({label,graph})+'\n');
 });
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('print'));
 lua.lua_pushcfunction(L,L=>{const label=to_jsstring(lauxlib.luaL_checkstring(L,1)),raw=to_jsstring(lauxlib.luaL_checkstring(L,2));lua.lua_pushstring(L,to_luastring(normalizeCardUpgradeError(label,raw)));return 1;});lua.lua_setglobal(L,to_luastring('CARD_UPGRADE_NORMALIZE_ERROR'));
 lua.lua_pushcfunction(L,L=>{diagnostics.push({label:to_jsstring(lauxlib.luaL_checkstring(L,1)),raw:to_jsstring(lauxlib.luaL_checkstring(L,2)),normalized:to_jsstring(lauxlib.luaL_checkstring(L,3))});return 0;});lua.lua_setglobal(L,to_luastring('CARD_UPGRADE_DIAGNOSTIC'));
 let source="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;\n";
 const files=variant==='before'?cardUpgradeBefore.files:Object.fromEntries(readdirSync('src/lua').filter(name=>name.endsWith('.lua')).sort().map(name=>[name.slice(0,-4),{path:'src/lua/'+name,source:readFileSync('src/lua/'+name,'utf8').replaceAll('\r\n','\n')}]));
 assert.equal(Object.keys(cardUpgradeBefore.files).length,333,'complete immutable handwritten baseline');
 const generated={},handwritten={};
 for(const name of Object.keys(generatedRuntimeModules)){
  const value=readFileSync(`build/lua/${name}.lua`,'utf8').replaceAll('\r\n','\n');generated[name]=hash(value);
  source+=`package.preload[${luaString(name)}]=function(...)return assert(load(${luaString(value)},${luaString('@build/lua/'+name+'.lua')}))(...)end;\n`;
 }
 for(const [name,file]of Object.entries(files)){
  handwritten[name]=hash(file.source);
  source+=`package.preload[${luaString(name)}]=function(...)return assert(load(${luaString(file.source)},${luaString('@'+file.path)}))(...)end;\n`;
 }
 // An unknown handwritten dependency cannot fall back through package.path to
 // the current tree. Each side executes only its own complete frozen corpus.
 const names=[...Object.keys(files),...Object.keys(generated)];
 source+=`do local allowed={${names.map(name=>`[${luaString(name)}]=true`).join(',')}};local raw=require;require=function(name)if type(name)=='string'and name:match('^abyss_')then assert(allowed[name],'CARD_UPGRADE_CORPUS_UNKNOWN '..name)end;return raw(name)end end\n`;
 if(mutation){
  assert.equal(variant,'after');assert(Object.hasOwn(files,mutation.name));
  source+=`package.preload[${luaString(mutation.name)}]=function(...)return assert(load(${luaString(mutation.source)},${luaString('@src/lua/'+mutation.name+'.lua')}))(...)end;\n`;
 }
 source+=prelude+'\n';
 if(fixture!==null){assert.equal(typeof fixture,'string');source+=`dofile(${luaString(fixture)})`;}
 const started=performance.now(),status=lauxlib.luaL_dostring(L,to_luastring(source));
 let error=null,errorType=null;
 if(status!==lua.LUA_OK){
  errorType=to_jsstring(lua.lua_typename(L,lua.lua_type(L,-1)));
  error=errorType==='string'?to_jsstring(lua.lua_tostring(L,-1)):`Lua ${errorType} error (complete object retained in graph)`;
  const index=lua.lua_absindex(L,-1);
  lua.lua_getglobal(L,to_luastring('CARD_UPGRADE_GRAPH_WRITE'));lua.lua_pushvalue(L,index);
  lua.lua_pushstring(L,to_luastring('uncaught fixture error'));lua.lua_pushboolean(L,true);
  assert.equal(lua.lua_pcall(L,3,0,0),lua.LUA_OK,'uncaught error graph sink');
 }
 const elapsedMs=performance.now()-started;lua.lua_close(L);
 if(status===lua.LUA_OK){
  assert(graphs.length>0&&bytes>0,'successful dedicated VM must emit a nonempty complete graph stream');
  assert(hasObjectFields,'graph stream must contain actual complete object fields');
 }
 return {status,error,errorType,graphs,logs,diagnostics,bytes,generated,handwritten,traceFile,elapsedMs,definitionCount:definitions.size};
}
export function runCardUpgrade(variant,fixture,options={}){
 mkdirSync('build/card-upgrade-ownership',{recursive:true});const directory=mkdtempSync('build/card-upgrade-ownership/process-');
 const input=directory+'/input.json';writeFileSync(input,JSON.stringify({variant,fixture,options:{...options,traceFile:directory+'/graphs.jsonl'}}));
 const started=performance.now();
 const result=spawnSync(process.execPath,['--max-old-space-size=1024',fileURLToPath(new URL('./card-upgrade-ownership-process.mjs',import.meta.url)),input],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
 writeFileSync(directory+'/process.json',JSON.stringify({variant,fixture,elapsedMs:performance.now()-started,status:result.status,signal:result.signal,error:result.error?.message??null},null,2)+'\n');
 writeFileSync(directory+'/stdout.log',result.stdout??'');writeFileSync(directory+'/stderr.log',result.stderr??'');
 assert(!result.error&&!result.signal&&result.status===0,'Card upgrade VM process failed: '+JSON.stringify({directory,status:result.status,signal:result.signal,error:result.error?.message,stderr:result.stderr}));
 return JSON.parse(result.stdout);
}
