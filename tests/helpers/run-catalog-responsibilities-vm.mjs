import {readFileSync,writeFileSync,appendFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {source,fixture}=JSON.parse(readFileSync(0,'utf8'));
const before=readFileSync('tests/fixtures/run-catalog-responsibilities-before.lua','utf8').replaceAll('\r\n','\n');
const moved=source!==before;
const statement="if generated[s.id]then assert(statusCompatible(s,generated[s.id]),'incompatible caller Power: '..s.id)";
assert.equal(before.split('\n')[141].trim(),statement);
if(moved)assert.equal(source.split('\n')[142].trim(),statement);
const observedError='src/lua/abyss_run_card_catalog.lua:143: incompatible caller Power: rushdown';
const originalError='src/lua/abyss_run_card_catalog.lua:142: incompatible caller Power: rushdown';
const output=process.argv[2];writeFileSync(output,'');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);let checkpoints=0;const relocatedErrors=[];
lua.lua_pushcfunction(L,L=>{relocatedErrors.push(to_jsstring(lua.lua_tostring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('CATALOG_RELOCATED'));
installLuaGraphObserver(L,'CATALOG_GRAPH',(label,graph)=>{appendFileSync(output,label+' '+graph+'\n');checkpoints++;});
const program=`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
package.preload.abyss_run_card_catalog=function()return assert(load(${luaString(source)},'@src/lua/abyss_run_card_catalog.lua'))()end
local Catalog=require('abyss_run_card_catalog')
for _,name in ipairs({'prepareSelected','prepare','finishMetadata'})do
 local original=Catalog[name]
 Catalog[name]=function(...)
  local args=table.pack(...)
  CATALOG_GRAPH_WRITE({args=args},name..':before',true)
  local result=table.pack(pcall(original,...))
  local observed=result
  if ${moved} and result[1]==false and result[2]==${luaString(observedError)} then
   observed={n=result.n,table.unpack(result,1,result.n)}
   observed[2]=${luaString(originalError)}
   CATALOG_RELOCATED(result[2])
  end
  CATALOG_GRAPH_WRITE({args=args,result=observed},name..':after',true)
  if not result[1]then error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
end
print=function()end
dofile(${luaString(fixture)})
CATALOG_GRAPH_WRITE({complete=true},'complete',true)
`;
const status=lauxlib.luaL_dostring(L,to_luastring(program));
const error=status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1));
lua.lua_close(L);console.log(JSON.stringify({status,error,checkpoints,relocatedErrors}));
