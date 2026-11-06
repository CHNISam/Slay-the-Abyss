import {createRequire} from 'node:module';
import {writeFileSync,appendFileSync} from 'node:fs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {relicLifecycleRevision,relicLifecycleArchiveSha256,relicLifecycleGroups,lifecycleHash,relicLifecycleFrozenPrelude,purgeA27FrozenPrelude,relicPurgeA27Revision,relicPurgeA27ArchiveSha256,relicLifecycleGeneratedBindings} from './relic-lifecycle-baseline.mjs';
const require=createRequire(import.meta.url),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const [group,variant,directory,mode]=process.argv.slice(2);
if(!relicLifecycleGroups.includes(group)||!['frozen391','frozena27','current'].includes(variant)||!['raw','trace','isolation'].includes(mode))throw Error('registered independent lifecycle VM');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const loadedFrozen=[],frozen=variant!=='current',trace=mode==='trace';let snapshots=0;
const tracePath=`${directory}/trace.jsonl`;writeFileSync(tracePath,'');
if(trace)installLuaGraphObserver(L,'RELIC_LIFECYCLE_GRAPH',(label,graph)=>{
 snapshots++;appendFileSync(tracePath,JSON.stringify({label,graph:JSON.parse(graph)})+'\n');
});
if(frozen){
 if(mode==='isolation')lauxlib.luaL_dostring(L,to_luastring(`RELIC_TRAP_CALLS=0;for _,name in ipairs({'abyss_relic_queries','abyss_purge_candidates','abyss_relic_combat_hooks','abyss_relic_family_combat'})do package.preload[name]=function()RELIC_TRAP_CALLS=RELIC_TRAP_CALLS+1;return {}end end`));
 const prelude=variant==='frozena27'?purgeA27FrozenPrelude():relicLifecycleFrozenPrelude();
 if(lauxlib.luaL_dostring(L,to_luastring(prelude))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
}
lua.lua_pushboolean(L,trace);lua.lua_setglobal(L,to_luastring('RELIC_LIFECYCLE_TRACE'));
const probe=`for _,name in ipairs({'abyss_relic_queries','abyss_purge_candidates','abyss_relic_combat_hooks','abyss_relic_family_combat'})do local ok,why=pcall(require,name);if ${variant==='frozena27'?'true':'false'} and name=='abyss_relic_queries'then assert(ok and type(why)=='table','original a27 query source allowed')else assert(not ok and tostring(why):find('[RELIC_FROZEN_SOURCE]',1,true),'explicit frozen guard must reject existing live preload: '..name)end end;assert(RELIC_TRAP_CALLS==0,'live new source trap ran');print('RELIC_FROZEN_ISOLATION_PASS '..tostring(RELIC_TRAP_CALLS))`;
const source=to_luastring(`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;`+(mode==='isolation'?probe:`dofile('tests/lua/relic_lifecycle_${group}.lua')`));
const status=lauxlib.luaL_dostring(L,source);
if(status!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1))??'nonstring lifecycle fixture failure');process.exitCode=1;lua.lua_pop(L,1);}
if(frozen&&status===lua.LUA_OK&&lauxlib.luaL_dostring(L,to_luastring('assert(RELIC_LIFECYCLE_FROZEN.audit())'))!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exitCode=1;lua.lua_pop(L,1);}
const coverage={};lua.lua_getglobal(L,to_luastring('RELIC_LIFECYCLE_COVERAGE'));
if(lua.lua_istable(L,-1)){lua.lua_pushnil(L);while(lua.lua_next(L,-2)){coverage[to_jsstring(lua.lua_tostring(L,-2))]=lua.lua_tonumber(L,-1);lua.lua_pop(L,1);}}
lua.lua_pop(L,1);
const array=name=>{const values=[];lua.lua_getglobal(L,to_luastring(name));if(lua.lua_istable(L,-1))for(let i=1;;i++){lua.lua_rawgeti(L,-1,i);if(lua.lua_isnil(L,-1)){lua.lua_pop(L,1);break;}values.push(to_jsstring(lua.lua_tostring(L,-1)));lua.lua_pop(L,1);}lua.lua_pop(L,1);return values;};
const registeredCases=array('RELIC_LIFECYCLE_REGISTERED'),executedCases=array('RELIC_LIFECYCLE_EXECUTED');
const loadedOrigins={};if(frozen){lua.lua_getglobal(L,to_luastring('RELIC_LIFECYCLE_FROZEN'));lua.lua_getfield(L,-1,to_luastring('loaded'));lua.lua_pushnil(L);while(lua.lua_next(L,-2)){const name=to_jsstring(lua.lua_tostring(L,-2)),origin=to_jsstring(lua.lua_tostring(L,-1));loadedOrigins[name]=origin;if(origin==='handwritten')loadedFrozen.push(name);lua.lua_pop(L,1);}lua.lua_pop(L,2);}
const generatedBindings=Object.fromEntries(Object.entries(relicLifecycleGeneratedBindings()).map(([name,{path,sha256}])=>[name,{path,sha256}]));
const graph=trace?require('node:fs').readFileSync(tracePath):Buffer.alloc(0);
writeFileSync(`${directory}/manifest.json`,JSON.stringify({schemaVersion:1,group,variant,trace,
 frozenRevision:frozen?(variant==='frozena27'?relicPurgeA27Revision:relicLifecycleRevision):null,frozenArchiveSha256:frozen?(variant==='frozena27'?relicPurgeA27ArchiveSha256:relicLifecycleArchiveSha256):null,
 preloadedSources:frozen?(variant==='frozena27'?330:329):0,loadedFrozen,loadedOrigins,generatedBindings,registeredCases,executedCases,checkpoints:snapshots,traceBytes:graph.length,traceSha256:lifecycleHash(graph),coverage},null,2)+'\n');
