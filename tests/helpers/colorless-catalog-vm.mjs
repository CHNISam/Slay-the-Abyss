import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {readFileSync,mkdirSync,writeFileSync,appendFileSync,mkdtempSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {basename} from 'node:path';
import {colorlessCatalogBefore} from './colorless-catalog-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {generatedRuntimeModules} from '../../scripts/build-native-candidate.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
export const colorlessHash=value=>createHash('sha256').update(value).digest('hex');
export function frozenColorlessSources(){return colorlessCatalogBefore;}
// Fresh VM and complete independent old graph. Generated data is deliberately
// the same input on both sides; unknown handwritten imports cannot fall through.
export function colorlessCatalogVm(variant,fixture,{prelude='',trace=false,mutation}={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const graphs=[],logs=[],loaded=[];let bytes=0;
 const traceFile=`build/colorless-catalog/${variant}-${basename(fixture,'.lua')}${mutation?'-mutation':''}.jsonl`;
 mkdirSync('build/colorless-catalog',{recursive:true});writeFileSync(traceFile,'');
 installLuaGraphObserver(L,'COLORLESS_GRAPH',(label,graph)=>{bytes+=Buffer.byteLength(graph);graphs.push({label,sha256:colorlessHash(graph)});appendFileSync(traceFile,JSON.stringify({label,graph:JSON.parse(graph)})+'\n');});
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('print'));
 lua.lua_pushcfunction(L,L=>{loaded.push(to_jsstring(lauxlib.luaL_checkstring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('COLORLESS_LOADED'));
 let source="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;\n";
 const files=variant==='before'?frozenColorlessSources().files:{};
 const generated={};
 for(const name of Object.keys(generatedRuntimeModules)){
  const value=readFileSync(`build/lua/${name}.lua`,'utf8').replaceAll('\r\n','\n');
  generated[name]=colorlessHash(value);
  source+=`package.preload[${luaString(name)}]=assert(load(${luaString(value)},${luaString('@build/lua/'+name+'.lua')}));\n`;
 }
 for(const [name,file]of Object.entries(files))source+=`package.preload[${luaString(name)}]=assert(load(${luaString(file.source)},${luaString('@'+file.path)}));\n`;
 if(variant==='before'){
  const names=[...Object.keys(files),...Object.keys(generated)];
  source+=`do local allowed={${names.map(n=>`[${luaString(n)}]=true`).join(',')}};local original=require;require=function(name)if type(name)=='string'and name:match('^abyss_')then assert(allowed[name],'COLORLESS_FROZEN_UNKNOWN '..name)end;local value=original(name);COLORLESS_LOADED(name);return value end end\n`;
 }
 if(mutation)source+=`package.preload[${luaString(mutation.name)}]=assert(load(${luaString(mutation.source)},${luaString('@src/lua/'+mutation.name+'.lua')}));\n`;
 source+=prelude+'\n';
 if(trace)source+=`
 local C=require('abyss_combat');local depth=0
 local function observe(owner,name)
  local original=assert(owner[name]);owner[name]=function(state,...)
   local args=table.pack(...);local outer=depth==0;depth=depth+1
   local result=table.pack(pcall(original,state,...));depth=depth-1
   if outer then COLORLESS_GRAPH_WRITE({state=state,args=args,returned=result},name)end
   if not result[1]then error(result[2],0)end
   return table.unpack(result,2,result.n)
  end
 end

 for _,name in ipairs({'play','chooseCard','endTurn'})do observe(C,name)end
 `;
 source+=`dofile(${luaString(fixture)})`;
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 const error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));lua.lua_close(L);
 return {status,error,graphs,logs,loaded,bytes,generated,traceFile};
}

// Every side runs in its own bounded process so a previous full VM cannot keep
// its object graph alive until an unrelated later case triggers JS collection.
export function runColorlessCatalog(variant,fixture,options={}){
 mkdirSync('build/colorless-catalog',{recursive:true});
 const directory=mkdtempSync('build/colorless-catalog/process-');
 const input=directory+'/input.json';writeFileSync(input,JSON.stringify({variant,fixture,options}));
 const result=spawnSync(process.execPath,['--max-old-space-size=1024',fileURLToPath(new URL('./colorless-catalog-process.mjs',import.meta.url)),input],{
  encoding:'utf8',timeout:30000,maxBuffer:1024*1024,
 });
 writeFileSync(directory+'/process.json',JSON.stringify({status:result.status,signal:result.signal,error:result.error?.message??null}));
 writeFileSync(directory+'/stdout.log',result.stdout??'');writeFileSync(directory+'/stderr.log',result.stderr??'');
 assert(!result.error&&!result.signal&&result.status===0,'Colorless VM process failed: '+JSON.stringify({status:result.status,signal:result.signal,error:result.error?.message,stderr:result.stderr}));
 return JSON.parse(result.stdout);
}
