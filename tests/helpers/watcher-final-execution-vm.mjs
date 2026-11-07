import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {watcherExecutionBefore} from './watcher-final-execution-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
// Only verified moved sites with identical source and error bodies are comparable.
// Never rewrite the thrown value itself, table errors, or unrecognized locations.
const errorSites=[
 [243,243,"assert(M.availablePowers[effect.status],'unsupported Watcher final Power')",'unsupported Watcher final Power'],
 [265,277,"assert(not state.pendingChoice,'another choice is pending')",'another choice is pending'],
 [271,283,"state.pendingChoice={op='watcher_final',kind=kind,token=state.choiceSerial,turn=state.turn,using=state.pendingPlay.uid,","attempt to index a nil value (field 'pendingPlay')"],
 [340,376,"error('unsupported Watcher final effect: '..tostring(op))",'unsupported Watcher final effect: unsupported'],
];
export function comparableWatcherError(value){
 if(typeof value!=='string')return value;
 for(const [before,after,,body] of errorSites){
  if(value===`src/lua/abyss_watcher_final_cards.lua:${after}: ${body}`)
   return `src/lua/abyss_watcher_final_cards.lua:${before}: ${body}`;
 }
 return value;
}
function verifyErrorSites(){
 const before=watcherExecutionBefore.split('\n');
 const after=readFileSync('src/lua/abyss_watcher_final_cards.lua','utf8').replaceAll('\r\n','\n').split('\n');
 for(const [oldLine,newLine,statement] of errorSites){
  assert(before[oldLine-1].includes(statement),`before error site ${oldLine}`);
  assert(after[newLine-1].includes(statement),`after error site ${newLine}`);
 }
}
export function watcherExecutionVm(variant,fixture,{mutation}={}){
 verifyErrorSites();
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const checkpoints=[],logs=[];let bytes=0;
 installLuaGraphObserver(L,'WATCHER_GRAPH',(label,graph)=>{
  bytes+=Buffer.byteLength(graph);checkpoints.push({label,sha256:createHash('sha256').update(graph).digest('hex')});
 });
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});
 lua.lua_setglobal(L,to_luastring('print'));
 lua.lua_pushcfunction(L,L=>{lua.lua_pushstring(L,to_luastring(comparableWatcherError(to_jsstring(lauxlib.luaL_checkstring(L,1)))));return 1;});
 lua.lua_setglobal(L,to_luastring('WATCHER_ERROR_LOCATION'));
 const source=mutation??(variant==='before'?watcherExecutionBefore:null);
 let prelude="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;";
 if(source)prelude+=`package.preload.abyss_watcher_final_cards=assert(load(${luaString(source)},'@src/lua/abyss_watcher_final_cards.lua'));`;
 prelude+=`
 local W=require('abyss_watcher_final_cards');local C=require('abyss_combat')
 local execute=W.execute
 WATCHER_EXECUTE_UNOBSERVED=execute
 W.execute=function(combat,state,effect,queue)
  local result=table.pack(pcall(execute,combat,state,effect,queue))
  local observed=result
  if not result[1] and type(result[2])=='string' then
   observed=table.pack(table.unpack(result,1,result.n));observed[2]=WATCHER_ERROR_LOCATION(result[2])
  end
  WATCHER_GRAPH_WRITE({state=state,effect=effect,returned=observed},'effect:'..tostring(effect.op))
  if not result[1]then error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
 local depth=0
 for _,name in ipairs({'play','chooseCard','choosePile','endTurn'})do
  local original=assert(C[name])
  C[name]=function(state,...)
   local outer=depth==0;depth=depth+1
   local result=table.pack(pcall(original,state,...));depth=depth-1
   if outer then WATCHER_GRAPH_WRITE({state=state,returned=result},name)end
   if not result[1]then error(result[2],0)end
   return table.unpack(result,2,result.n)
  end
 end
 dofile(${luaString(fixture)})`;
 const status=lauxlib.luaL_dostring(L,to_luastring(prelude));
 const error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));
 lua.lua_close(L);
 return {status,error,checkpoints,logs,bytes};
}
