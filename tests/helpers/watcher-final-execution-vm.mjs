import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {watcherExecutionBefore} from './watcher-final-execution-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
export function watcherExecutionVm(variant,fixture,{mutation}={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const checkpoints=[],logs=[];let bytes=0;
 installLuaGraphObserver(L,'WATCHER_GRAPH',(label,graph)=>{
  bytes+=Buffer.byteLength(graph);checkpoints.push({label,sha256:createHash('sha256').update(graph).digest('hex')});
 });
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});
 lua.lua_setglobal(L,to_luastring('print'));
 const source=mutation??(variant==='before'?watcherExecutionBefore:null);
 let prelude="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;";
 if(source)prelude+=`package.preload.abyss_watcher_final_cards=assert(load(${luaString(source)},'@src/lua/abyss_watcher_final_cards.lua'));`;
 prelude+=`
 local W=require('abyss_watcher_final_cards');local C=require('abyss_combat')
 local execute=W.execute
 WATCHER_EXECUTE_UNOBSERVED=execute
 W.execute=function(combat,state,effect,queue)
  local result=table.pack(pcall(execute,combat,state,effect,queue))
  WATCHER_GRAPH_WRITE({state=state,effect=effect,returned=result},'effect:'..tostring(effect.op))
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
