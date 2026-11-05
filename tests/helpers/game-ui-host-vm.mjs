// Fresh process/VM, with a native observer to avoid quadratic Fengari string work.
import {createRequire} from 'node:module';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
import {gzipSync} from 'node:zlib';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const output=[];const write=process.stdout.write.bind(process.stdout);let bytes=0;
process.stdout.write=(chunk)=>{const buffer=Buffer.from(chunk);bytes+=buffer.length;
 if(bytes>128*1024*1024)throw Error('decoded Host trace exceeds fixed 128MiB bound');output.push(buffer);return true;};
installLuaGraphObserver(L,'ABYSS_HOST_GRAPH',(label,graph)=>process.stdout.write(label+' '+graph+'\n'));
const scenario=process.argv[3]||'';
const total=scenario==='short-route'?18:scenario==='short-chapters'||scenario==='short-egg'?11:scenario==='short-overlays'?13:scenario.startsWith('short-')?7:scenario?1:35;
const from=Number(process.argv[4]||1),to=Number(process.argv[5]||total);
const source=`package.path='./build/lua/?.lua;./src/lua/?.lua;'..package.path;ABYSS_HOST_FULL_TRACE=true;ABYSS_HOST_SEED=${Number(process.argv[2])};ABYSS_HOST_CONSTRUCTOR=${JSON.stringify(scenario)};ABYSS_HOST_FROM=${from};ABYSS_HOST_TO=${to};ABYSS_HOST_TOTAL=${total};local co=coroutine.create(function()dofile('tests/lua/support/game_ui_host_trace.lua')end);local ok,tag=coroutine.resume(co);if not ok then error(tag,0)end;assert(coroutine.status(co)=='dead' or tag=='HOST_WINDOW_DONE','unexpected driver yield');assert(ABYSS_HOST_EXECUTED==math.min(${to},${total}),'incorrect executed command prefix')`;
if(lauxlib.luaL_dostring(L,to_luastring(source+`;assert(${to}<${total} or coroutine.status(co)=='dead','declared total leaves unexecuted commands')`))!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exitCode=1;}
write('HOST_TRACE_GZIP '+gzipSync(Buffer.concat(output)).toString('base64')+'\n');
