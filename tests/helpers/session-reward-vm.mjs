// Fresh bounded VM for the three-source reward-capability differential.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './lua-graph-observer.mjs';
const require=createRequire(import.meta.url),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const [variant,group,directory]=process.argv.slice(2);
assert(['old','current'].includes(variant));assert(['potion','events','dynamic'].includes(group));
const archive=readFileSync(new URL('./session-reward-before.json.gz',import.meta.url));
const hash=s=>createHash('sha256').update(s).digest('hex');
assert.equal(hash(archive),'d0a42f51486f79bca22b34a8f0457ca0f78e4917310ad72e70ef89c836a9b57c');
const proof=JSON.parse(gunzipSync(archive));assert.equal(proof.revision,'2c85bc618f39a4706dbc108eca0ebe5797630081');
assert.deepEqual(Object.keys(proof.files),['abyss_event_combat','abyss_event_combat_routes','abyss_potion_rewards']);
for(const file of Object.values(proof.files)){
 assert.equal(hash(file.source),file.sha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(file.source)+'\0'+file.source).digest('hex'),file.gitBlob);
}
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const records=[];let bytes=0;
installLuaGraphObserver(L,'SESSION_GRAPH',(label,graph)=>{const line=JSON.stringify({label,graph:JSON.parse(graph)});bytes+=Buffer.byteLength(line)+1;assert(bytes<=1024**3,'original graph output budget');records.push(line);});
let prelude="package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n";
if(variant==='old')for(const [name,file]of Object.entries(proof.files))prelude+=`package.preload[${luaString(name)}]=assert(load(${luaString(file.source)},${luaString('@src/lua/'+name+'.lua')}))\n`;
prelude+=`SESSION_GROUP=${luaString(group)}\nSESSION_OLD=${variant==='old'}\n`;
const source=prelude+readFileSync('tests/lua/support/session_reward_capabilities.lua','utf8');
try{
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
 assert(records.length>0,'actual complete graph checkpoints');mkdirSync(directory,{recursive:true});
 const graph=records.join('\n')+'\n';writeFileSync(directory+'/graph.jsonl',graph);
 console.log(JSON.stringify({variant,group,checkpoints:records.length,bytes:Buffer.byteLength(graph),sha256:hash(graph)}));
}finally{lua.lua_close(L);}
