import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {m7FinalBefore} from './m7-core-final-source-inverse.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
export function finalCoreVm(variant,fixture,{mutation}={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const checkpoints=[],logs=[];let bytes=0;
 installLuaGraphObserver(L,'M7_GRAPH',(label,graph)=>{
  bytes+=Buffer.byteLength(graph);checkpoints.push({label,sha256:createHash('sha256').update(graph).digest('hex')});
 });
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});
 lua.lua_setglobal(L,to_luastring('print'));
 let prelude="package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;";
 if(variant==='before')for(const [name,file]of Object.entries(m7FinalBefore.files))
  prelude+=`package.preload[${luaString(name)}]=assert(load(${luaString(file.source)},${luaString('@src/lua/'+name+'.lua')}));`;
 if(mutation)prelude+=`package.preload[${luaString(mutation.name)}]=assert(load(${luaString(mutation.source)},${luaString('@src/lua/'+mutation.name+'.lua')}));`;
 prelude+=`
 local C=require('abyss_combat');local V=require('abyss_original_v4')
 local execute=V.execute
 V.execute=function(combat,state,...)
  local result=table.pack(pcall(execute,combat,state,...))
  M7_GRAPH_WRITE({state=state,returned=result},'execute-partial')
  if not result[1]then error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
 local depth=0
 local function observe(owner,name)
  local original=assert(owner[name])
  owner[name]=function(state,...)
   local outer=depth==0;depth=depth+1
   local result=table.pack(pcall(original,state,...));depth=depth-1
   if outer then M7_GRAPH_WRITE({state=state,returned=result},name)end
   if not result[1]then error(result[2],0)end
   return table.unpack(result,2,result.n)
  end
 end
 for _,name in ipairs({'play','chooseCard','endTurn'})do observe(C,name)end
 dofile(${luaString(fixture)})
 ${fixture.endsWith('/original_v4_contract.lua')?`
 local F=require('support.original_v4_fixture')
 do
  local s=F.state('HT',39);local sentinel={stage='post-payment'};local snapshot=V.snapshot
  V.snapshot=function()error(sentinel,0)end
  local ok,why=pcall(V.execute,C,s,{effect={raw=s.catalog.cards['HT2-003'].originalV4},target=s.enemies[1]})
  V.snapshot=snapshot;assert(not ok and why==sentinel and s.player.hp==36 and not s.resolvingEffects)
  print('M7_PARTIAL_PAYMENT_PASS')
 end
 do
  local s=F.state('HT',60);local sentinel={stage='post-damage'};local damage=C.damage
  C.damage=function(...)damage(...);error(sentinel,0)end
  local ok,why=pcall(V.execute,C,s,{effect={raw=s.catalog.cards['HT2-022'].originalV4},target=s.enemies[1]})
  C.damage=damage;assert(not ok and why==sentinel and s.enemies[1].hp<500 and not s.resolvingEffects)
  print('M7_PARTIAL_DAMAGE_PASS')
 end
 `:''}`;
 const status=lauxlib.luaL_dostring(L,to_luastring(prelude));
 const error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));
 lua.lua_close(L);
 return {status,error,checkpoints,logs,bytes};
}
