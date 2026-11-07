// Independent bounded VM, with full state/alias/return observations.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {comparableDefectPlanError,verifyDefectPlanErrorSites} from './defect-plan-source-inverse.mjs';
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=createRequire(import.meta.url)('fengari');
const {source,fixture,mode,group,output}=JSON.parse(readFileSync(0,'utf8'));
verifyDefectPlanErrorSites(readFileSync('src/lua/abyss_defect_engine_cards.lua','utf8'));
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const records=[],logs=[];let bytes=0;
installLuaGraphObserver(L,'DEFECT_PLAN_GRAPH',(label,graph)=>{
 const row=JSON.stringify({label,graph:JSON.parse(graph)});bytes+=Buffer.byteLength(row)+1;
 assert(bytes<=1024**3,'full graph output bound');records.push(row);
});
lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('print'));
lua.lua_pushcfunction(L,L=>{lua.lua_pushstring(L,to_luastring(comparableDefectPlanError(to_jsstring(lauxlib.luaL_checkstring(L,1)))));return 1;});lua.lua_setglobal(L,to_luastring('DEFECT_ERROR_LOCATION'));
const prelude=`package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
 package.preload.abyss_defect_engine_cards=assert(load(${luaString(source)},'@src/lua/abyss_defect_engine_cards.lua'))
 local E=require('abyss_defect_engine_cards');local C=require('abyss_combat')
 local function observation(result)
  if result[1] or type(result[2])~='string'then return result end
  local observed=table.pack(table.unpack(result,1,result.n));observed[2]=DEFECT_ERROR_LOCATION(result[2]);return observed
 end
 if ${luaString(mode)}=='plans'then
  local original=E.planEffect
  E.planEffect=function(state,effect,context)
   local id=effect.op
   DEFECT_PLAN_GRAPH_WRITE({state=state,effect=effect,context=context},'before:'..tostring(id))
   local returned=table.pack(pcall(original,state,effect,context))
   DEFECT_PLAN_GRAPH_WRITE({state=state,effect=effect,context=context,returned=observation(returned)},'plan:'..tostring(id))
   if not returned[1]then error(returned[2],0)end
   return table.unpack(returned,2,returned.n)
  end
 else
  local depth=0
  for _,name in ipairs({'play','endTurn'})do
   local original=assert(C[name])
   C[name]=function(state,...)
    local outer=depth==0;depth=depth+1
    local owners={hand=state.hand,draw=state.draw,discard=state.discard,exhaust=state.exhaust,orbs=state.orbs,rng=state.cardRandomRng,history=state.orbChannelCounts}
    local returned=table.pack(pcall(original,state,...));depth=depth-1
    if outer then DEFECT_PLAN_GRAPH_WRITE({state=state,owners=owners,returned=observation(returned)},name)end
    if not returned[1]then error(returned[2],0)end
    return table.unpack(returned,2,returned.n)
   end
  end
 end
 DEFECT_PLAN_BOUNDARY_GROUP=${group??'nil'}
 dofile(${luaString(fixture)})`;
try{
 const status=lauxlib.luaL_dostring(L,to_luastring(prelude)),error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));
 writeFileSync(output,records.length?records.join('\n')+'\n':'');
 console.log(JSON.stringify({status,error,checkpoints:records.length,bytes,labels:records.map(r=>JSON.parse(r).label),logs}));
}finally{lua.lua_close(L);}
