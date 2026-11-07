// One fresh, bounded VM per invocation. Full graph bytes go to the caller-owned
// temporary file; stdout only returns status, never a truncated graph oracle.
import {readFileSync,writeFileSync,appendFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {source,group}=JSON.parse(readFileSync(0,'utf8'));
const output=process.argv[2];writeFileSync(output,'');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);let checkpoints=0;
installLuaGraphObserver(L,'ABYSS_INVENTORY_GRAPH',(label,graph)=>{
 appendFileSync(output,label+' '+graph+'\n');checkpoints++;
});
const program=`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\nABYSS_INVENTORY_GROUP=${luaString(group)}\n`
 +`package.preload.abyss_inventory=function()return assert(load(${luaString(source)},'inventory-source'))()end\n`
 +readFileSync('tests/helpers/inventory-responsibilities.lua','utf8');
const status=lauxlib.luaL_dostring(L,to_luastring(program));
const error=status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1));
lua.lua_close(L);console.log(JSON.stringify({status,error,checkpoints}));
