import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';

const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const fixture=readFileSync(new URL('../lua/snapshot_flat.lua',import.meta.url),'utf8');
const referenceTags=new Set(['table','function','userdata','thread']);

// A fresh VM/module/observer per source; no package.loaded or owner state crosses
// the oracle/candidate boundary. Reconstruct every complete checkpoint from the
// existing observer's stable-ID stream, including detached original objects.
export function runSnapshotFlat(source,{mode='contract',iterations=40}={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const trace=[],definitions=new Map();let error=null;
 installLuaGraphObserver(L,'SNAPSHOT_GRAPH',(label,bytes)=>{
  const graph=JSON.parse(bytes);
  for(const definition of graph.definitions)definitions.set(definition[1],definition);
  const reachable=new Map();
  function visit(value){
   if(!Array.isArray(value)||!referenceTags.has(value[0]))return;
   const id=value[1];if(reachable.has(id))return;
   const definition=definitions.get(id);
   if(!definition)throw Error(`missing graph definition ${id}`);
   reachable.set(id,definition);
   for(const [key,field]of definition[2]){visit(key);visit(field);}
   visit(definition[3]);
  }
  visit(graph.root);
  trace.push({label,graph:{root:graph.root,definitions:[...reachable.values()].sort((a,b)=>a[1]-b[1])}});
 });
 const stringGlobal=(name,value)=>{lua.lua_pushstring(L,to_luastring(value));lua.lua_setglobal(L,to_luastring(name));};
 stringGlobal('SNAPSHOT_SOURCE',source);
 stringGlobal('SNAPSHOT_MODE',mode);
 lua.lua_pushinteger(L,iterations);lua.lua_setglobal(L,to_luastring('SNAPSHOT_ITERATIONS'));
 try{
  if(lauxlib.luaL_loadbuffer(L,to_luastring(fixture),null,to_luastring('@tests/lua/snapshot_flat.lua'))!==lua.LUA_OK
   ||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)error=to_jsstring(lua.lua_tostring(L,-1));
 }finally{lua.lua_close(L);}
 return {trace,error};
}
