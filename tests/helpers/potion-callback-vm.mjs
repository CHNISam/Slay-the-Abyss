import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {readFileSync,readdirSync,mkdirSync,writeFileSync,appendFileSync,mkdtempSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';
import {potionCallbackBefore} from './potion-callback-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {generatedRuntimeModules} from '../../scripts/build-native-candidate.mjs';
const require=createRequire(import.meta.url),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const hash=value=>createHash('sha256').update(value).digest('hex');
export function potionVm(variant,fixture,{prelude='',mutation,traceFile}={}){
 assert(['before','after'].includes(variant));
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const graphs=[],logs=[],definitions=new Set();let bytes=0,hasObjectFields=false;
 assert(traceFile,'a per-process graph sink is required');writeFileSync(traceFile,'');
 installLuaGraphObserver(L,'POTION_GRAPH',(label,serialized)=>{
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
 let source="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;\n";
 const files=variant==='before'?potionCallbackBefore.files:Object.fromEntries(readdirSync('src/lua').filter(name=>name.endsWith('.lua')).sort().map(name=>[name.slice(0,-4),{path:'src/lua/'+name,source:readFileSync('src/lua/'+name,'utf8').replaceAll('\r\n','\n')}]));
 assert.equal(Object.keys(potionCallbackBefore.files).length,333,'complete immutable handwritten baseline');
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
 source+=`do local allowed={${names.map(name=>`[${luaString(name)}]=true`).join(',')}};local raw=require;require=function(name)if type(name)=='string'and name:match('^abyss_')then assert(allowed[name],'POTION_CORPUS_UNKNOWN '..name)end;return raw(name)end end\n`;
 if(mutation){
  assert.equal(variant,'after');assert(Object.hasOwn(files,mutation.name));
  source+=`package.preload[${luaString(mutation.name)}]=assert(load(${luaString(mutation.source)},${luaString('@src/lua/'+mutation.name+'.lua')}));\n`;
 }
 source+=prelude+'\n';
 if(fixture!==null){assert.equal(typeof fixture,'string');source+=`dofile(${luaString(fixture)})`;}
 const started=performance.now(),status=lauxlib.luaL_dostring(L,to_luastring(source));
 let error=null,errorType=null;
 if(status!==lua.LUA_OK){
  errorType=to_jsstring(lua.lua_typename(L,lua.lua_type(L,-1)));
  error=errorType==='string'?to_jsstring(lua.lua_tostring(L,-1)):`Lua ${errorType} error (complete object retained in graph)`;
  const index=lua.lua_absindex(L,-1);
  lua.lua_getglobal(L,to_luastring('POTION_GRAPH_WRITE'));lua.lua_pushvalue(L,index);
  lua.lua_pushstring(L,to_luastring('uncaught fixture error'));lua.lua_pushboolean(L,true);
  assert.equal(lua.lua_pcall(L,3,0,0),lua.LUA_OK,'uncaught error graph sink');
 }
 const elapsedMs=performance.now()-started;lua.lua_close(L);
 if(status===lua.LUA_OK){
  assert(graphs.length>0&&bytes>0,'successful dedicated VM must emit a nonempty complete graph stream');
  assert(hasObjectFields,'graph stream must contain actual complete object fields');
 }
 return {status,error,errorType,graphs,logs,bytes,generated,handwritten,traceFile,elapsedMs,definitionCount:definitions.size};
}
export function runPotion(variant,fixture,options={}){
 mkdirSync('build/potion-callback',{recursive:true});const directory=mkdtempSync('build/potion-callback/process-');
 const input=directory+'/input.json';writeFileSync(input,JSON.stringify({variant,fixture,options:{...options,traceFile:directory+'/graphs.jsonl'}}));
 const started=performance.now();
 const result=spawnSync(process.execPath,['--max-old-space-size=1024',fileURLToPath(new URL('./potion-callback-process.mjs',import.meta.url)),input],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
 writeFileSync(directory+'/process.json',JSON.stringify({variant,fixture,elapsedMs:performance.now()-started,status:result.status,signal:result.signal,error:result.error?.message??null},null,2)+'\n');
 writeFileSync(directory+'/stdout.log',result.stdout??'');writeFileSync(directory+'/stderr.log',result.stderr??'');
 assert(!result.error&&!result.signal&&result.status===0,'Potion VM process failed: '+JSON.stringify({directory,status:result.status,signal:result.signal,error:result.error?.message,stderr:result.stderr}));
 return JSON.parse(result.stdout);
}
