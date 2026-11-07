// Independent, bounded Lua VM. Preserve complete graphs and exact return arity.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {comparableAct1ChoiceError,verifyAct1ChoiceErrorSite} from './act1-choice-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {source,fixture,output,group}=JSON.parse(readFileSync(0,'utf8'));
verifyAct1ChoiceErrorSite(readFileSync('src/lua/abyss_act1_events.lua','utf8'));
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const records=[],logs=[];let bytes=0;
installLuaGraphObserver(L,'ACT1_GRAPH',(label,graph)=>{
 const row=JSON.stringify({label,graph:JSON.parse(graph)});bytes+=Buffer.byteLength(row)+1;
 assert(bytes<=1024**3,'complete graph output budget');records.push(row);
});
lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});
lua.lua_setglobal(L,to_luastring('print'));
lua.lua_pushcfunction(L,L=>{lua.lua_pushstring(L,to_luastring(comparableAct1ChoiceError(to_jsstring(lauxlib.luaL_checkstring(L,1)))));return 1;});
lua.lua_setglobal(L,to_luastring('ACT1_ERROR_LOCATION'));
const prelude=`package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
 package.preload.abyss_act1_events=assert(load(${luaString(source)},'@src/lua/abyss_act1_events.lua'))
 local A=require('abyss_act1_events');local N=require('abyss_nodes')
 local choose=A.choose
 A.choose=function(run,flow,choice,uid,...)
  local event=flow.event;local id=event.id;local old={event=event,deck=run.deck,relics=run.relics,relicPool=run.relicPool,miscRng=run.miscRng}
  local returned=table.pack(pcall(choose,run,flow,choice,uid,...))
  local observed=returned
  if not returned[1] and type(returned[2])=='string'then
   observed=table.pack(table.unpack(returned,1,returned.n));observed[2]=ACT1_ERROR_LOCATION(returned[2])
  end
  ACT1_GRAPH_WRITE({run=run,flow=flow,old=old,choice=choice,uid=uid,returned=observed},'choice:'..tostring(id))
  if not returned[1]then error(returned[2],0)end
  return table.unpack(returned,2,returned.n)
 end
 local chooseEvent=N.chooseEvent
 N.chooseEvent=function(run,...)
  local old={flow=run.nodeFlow,deck=run.deck,relics=run.relics,relicPool=run.relicPool,miscRng=run.miscRng}
  local returned=table.pack(pcall(chooseEvent,run,...))
  ACT1_GRAPH_WRITE({run=run,old=old,returned=returned},'node-choice')
  if not returned[1]then error(returned[2],0)end
  return table.unpack(returned,2,returned.n)
 end
 ACT1_BOUNDARY_GROUP=${group??'nil'}
 dofile(${luaString(fixture)})`;
try{
 const status=lauxlib.luaL_dostring(L,to_luastring(prelude));
 const error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));
 writeFileSync(output,records.length?records.join('\n')+'\n':'');
 console.log(JSON.stringify({status,error,checkpoints:records.length,bytes,logs}));
}finally{lua.lua_close(L);}
