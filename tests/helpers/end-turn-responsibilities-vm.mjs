import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,appendFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {source,fixture}=JSON.parse(readFileSync(0,'utf8'));
const before=readFileSync('tests/fixtures/end-turn-responsibilities-before.lua','utf8').replaceAll('\r\n','\n');
const maps=[];
for(const message of ['unsupported owner-end native callback','inconsistent Bomb Power','invalid temporary stat removal','missing captured damage source','unknown owner-end action','invalid exhaust acquisition history','invalid exhaust acquisition index','invalid exhaust acquisition entry','inconsistent exhaust acquisition history']){
 const sites=s=>s.split('\n').flatMap((line,i)=>line.includes("'"+message+"'")?[{line:line.trim(),number:i+1}]:[]);
 const prior=sites(before),now=sites(source);assert.equal(now.length,prior.length,'same exact error sites');
 for(let i=0;i<prior.length;i++){
  assert.equal(now[i].line,prior[i].line,'same exact throw statement');
  if(now[i].number!==prior[i].number)maps.push([`src/lua/abyss_end_turn_powers.lua:${now[i].number}: ${message}`,`src/lua/abyss_end_turn_powers.lua:${prior[i].number}: ${message}`]);
 }
}
const output=process.argv[2];writeFileSync(output,'');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);let checkpoints=0;const relocatedErrors=[];
lua.lua_pushcfunction(L,L=>{relocatedErrors.push(to_jsstring(lua.lua_tostring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('END_TURN_RELOCATED'));
installLuaGraphObserver(L,'END_TURN_GRAPH',(label,graph)=>{appendFileSync(output,label+' '+graph+'\n');checkpoints++;});
let program=`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
package.preload.abyss_end_turn_powers=function()return assert(load(${luaString(source)},'@src/lua/abyss_end_turn_powers.lua'))()end
END_TURN_ERRORS={${maps.map(([a,b])=>`[${luaString(a)}]=${luaString(b)}`).join(',')}}
`;
if(fixture==='matrix')program+=readFileSync('tests/helpers/end-turn-responsibilities.lua','utf8');
else program+=`
local C=require('abyss_combat')
for _,name in ipairs({'endTurn','chooseCard'})do
 local original=C[name]
 C[name]=function(state,...)
  local args=table.pack(...)
  END_TURN_GRAPH_WRITE({state=state,args=args},name..':before',true)
  local result=table.pack(pcall(original,state,...))
  END_TURN_GRAPH_WRITE({state=state,args=args,result=result},name..':after',true)
  if not result[1]then error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
end
print=function()end
dofile(${luaString(fixture)})
END_TURN_GRAPH_WRITE({complete=true},'complete',true)
`;
const status=lauxlib.luaL_dostring(L,to_luastring(program));
const error=status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1));
lua.lua_close(L);console.log(JSON.stringify({status,error,checkpoints,relocatedErrors}));
