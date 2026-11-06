import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
installLuaGraphObserver(L,'VISIBILITY_STATE',(label,graph)=>console.log('VISIBILITY_GRAPH '+graph));
const baseline=process.argv[2]==='before';
if(!baseline&&process.argv[2]!=='after')throw Error('expected before or after');
const execute=source=>{if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
if(baseline){
 const before=readFileSync('tests/fixtures/intent-visibility/before.lua','utf8');
 if(createHash('sha256').update(before.replaceAll('\r\n','\n')).digest('hex')!=='f535f2d14b15e8af3fe49bf3e3af45900b4cae4fcc8f8ccb29a407cf6fdcc6d9')throw Error('baseline source identity changed');
 execute(`package.preload.abyss_battle_render_actors=assert(load(${JSON.stringify(before)},'@visibility-before'))`);
}
const fixture=readFileSync('tests/lua/support/game_ui_fixture.lua','utf8');
const needle='return NativeContract.control(self,spec)';if(fixture.split(needle).length!==2)throw Error('fixture anchor changed');
lua.lua_pushstring(L,to_luastring(fixture.replace(needle,'ABYSS_HOST_CONTROL(self); '+needle)));lua.lua_setglobal(L,to_luastring('BASELINE_FIXTURE'));
const rows=[];let previous=[0,0,0,0,0];
lua.lua_pushjsfunction(L,state=>{
 const current=previous.map((_,i)=>lua.lua_tonumber(state,i+2));
 rows.push({phase:to_jsstring(lua.lua_tostring(state,1)),counts:current.map((value,i)=>value-previous[i])});previous=current;return 0;
});lua.lua_setglobal(L,to_luastring('BASELINE_MARK'));
let observer=readFileSync('scripts/runtime-baseline/observer.lua','utf8');
observer=observer.replace('for k in pairs(fields)do',"VISIBILITY_STATE_CONTROL(control,fields)\n for k in pairs(fields)do");
let host=readFileSync('scripts/runtime-baseline/host.lua','utf8');
host=host.replace("local observe=dofile('scripts/runtime-baseline/observer.lua')",`local observe=assert(load(${JSON.stringify(observer)},'@visibility-observer'))()`);
// Compare every reachable final Host/run/native field, aliases and metatables.
host+="\nVISIBILITY_STATE_WRITE({host=host,root=root},'final')\n";
execute(host);
console.log('VISIBILITY_COUNTS '+JSON.stringify(rows));
