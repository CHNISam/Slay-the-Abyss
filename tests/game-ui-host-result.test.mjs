import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {mainWindows,runPair} from './helpers/game-ui-host-equivalence.mjs';
import {installLuaGraphObserver} from './helpers/lua-graph-observer.mjs';
const require=createRequire(import.meta.url);
const resultWindows=mainWindows.slice(6,8);
assert.deepEqual(resultWindows,[[25,27],[28,30]],'result registration must retain both original three-checkpoint identity streams');

test('native graph writes preserve every returned-string byte and event order',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 function observe(nativeWrite){
  const output=[],L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  lua.lua_newuserdata(L,1);lua.lua_setglobal(L,to_luastring('probeUserdata'));
  installLuaGraphObserver(L,'ABYSS_HOST_GRAPH',(label,graph)=>output.push(label+' '+graph+'\n'));
  lua.lua_pushcfunction(L,L=>{output.push(to_jsstring(lua.lua_tostring(L,1))+'\n');return 0;});
  lua.lua_setglobal(L,to_luastring('print'));
  const source=`local function emit(label,value,stable)
    ${nativeWrite?'ABYSS_HOST_GRAPH_WRITE(value,label,stable)':'print(label.." "..ABYSS_HOST_GRAPH(value,{},stable))'}
   end
   local key={};local fn=function()end
   local child={value='中文 · 地图 😀',pack=table.pack(true,nil,false,nil)}
   local meta={__index={value='meta'}}
   local root=setmetatable({a=child,b=child,[true]=false,[key]=key,[fn]=fn,f=fn,g=fn,cfunc=math.sin,calias=math.sin,[math.sin]=math.sin},meta)
   local thread=coroutine.create(function()end)
   root[thread]=thread;root.thread=thread;root[probeUserdata]=probeUserdata;root.userdata=probeUserdata
   debug.setmetatable(probeUserdata,{value='userdata meta'})
   root.self=root
   local control=setmetatable({},{__index={alive=true,activeInHierarchy=true}})
   local backing={nested=child};ABYSS_HOST_GRAPH_CONTROL(control,backing);root.control=control;root.nativeRegistry={control}
   emit('HOST_SOURCES',root,false)
   print('HOST_EVENTS '..ABYSS_HOST_GRAPH_EVENT('native',control,table.unpack(child.pack,1,child.pack.n)))
   emit('HOST_TRACE',root,true)
   child.value='changed';meta.__index.value='changed meta';backing.nested={value=2}
   debug.getmetatable(probeUserdata).value='changed userdata meta'
   print('HOST_EVENTS '..ABYSS_HOST_GRAPH_EVENT('write',{nested=control},nil,child))
   emit('HOST_TRACE',root,true)
   child.value='中文 · 地图 😀';root.b={value=child.value};root.g=function()end;root.calias=math.cos;root[key]=nil
   root.control=nil;getmetatable(control).__index.alive=false;backing.nested=nil
   emit('HOST_TRACE',root,true)
   emit('HOST_TRACE',nil,true)`;
  const status=lauxlib.luaL_dostring(L,to_luastring(source));
  assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
  return output;
 }
 const returned=observe(false),written=observe(true);
 assert.deepEqual(written,returned,'complete JSON definitions, IDs, events and updates must be byte-identical');
 assert.equal(written.length,7);assert.match(written[0],/中文/);
 assert.match(written[1],/nativeControl/);assert.match(written.at(-1),/"root":\["nil"\]/);
 assert.match(written[5],/\[\["engine","alive"\],\["boolean",false\]\]/,'retired native control remains fully observed');
});

test('reference-push reuse ends at each observation and freshly reads warm and detached owners',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);installLuaGraphObserver(L);
 const original=lua.lua_toproxy;let pushes=0;
 lua.lua_toproxy=(...args)=>{pushes++;return original(...args);};
 try{
  const source=`local child={value=1};local root={}
   for i=1,100 do root['a'..i]=child end
   local first=ABYSS_HOST_GRAPH(root,{},true)
   child.value=2;local second=ABYSS_HOST_GRAPH(root,{},true)
   for i=1,100 do root['a'..i]=nil end
   local detached=ABYSS_HOST_GRAPH(root,{},true)
   child.value=3;root.a1=child;local returned=ABYSS_HOST_GRAPH(root,{},true)
   root.a2={value=3};local replaced=ABYSS_HOST_GRAPH(root,{},true)
   return first,second,detached,returned,replaced`;
  const status=lauxlib.luaL_dostring(L,to_luastring(source));
  assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
  const frames=Array.from({length:5},(_,i)=>JSON.parse(to_jsstring(lua.lua_tostring(L,i+1))));
  assert.equal(pushes,5,'one shared reference per first/second/returned, two after alias split, none while detached');
  assert.equal(frames[0].definitions.length,2);assert.equal(frames[1].definitions.length,1);
  assert.equal(frames[1].definitions[0][1],2);assert.match(JSON.stringify(frames[1]),/"number","2"/);
  assert.equal(frames[2].definitions.length,1);assert.deepEqual(frames[2].definitions[0][2],[]);
  assert.equal(frames[3].definitions.find(node=>node[1]===2)[2][0][1][1],'3','detached owner mutation is fresh on return');
  const fields=frames[4].definitions.find(node=>node[1]===1)[2];
  assert.notDeepEqual(fields[0][1],fields[1][1],'same-value replacement retains distinct reference identity');
 }finally{lua.lua_toproxy=original;}
});

test('result anchor observes replacement identity even when separate final graphs are equal',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 function observe(replace){
  const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);installLuaGraphObserver(L);
  const source=`local owner={value=1};local root={owner=owner,alias=owner}
   local plainBefore=ABYSS_HOST_GRAPH(root,{},false)
   local anchor=ABYSS_HOST_GRAPH(root,{},true)
   ${replace?'owner={value=1};root.owner=owner;root.alias=owner':''}
   local selected=ABYSS_HOST_GRAPH(root,{},true)
   local plainAfter=ABYSS_HOST_GRAPH(root,{},false)
   return anchor,selected,plainBefore,plainAfter`;
  const status=lauxlib.luaL_dostring(L,to_luastring(source));
  assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
  return Array.from({length:4},(_,i)=>to_jsstring(lua.lua_tostring(L,i+1)));
 }
 const original=observe(false),replacement=observe(true);
 assert.deepEqual(original.slice(2),replacement.slice(2),'isolated snapshots cannot detect the lifetime change');
 assert.equal(original[0],replacement[0],'the complete context checkpoint is identical');
 assert.notEqual(original[1],replacement[1],'shared stable IDs must detect replacement after the anchor');
});

test('original result windows detect detached-owner replacement that adjacent overlaps miss',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 const collector=readFileSync('tests/lua/support/game_ui_host_trace.lua','utf8');
 function fragment(start,end){
  assert.equal(collector.split(start).length,2,'one actual collector definition');
  const from=collector.indexOf(start),to=collector.indexOf(end,from);
  assert.ok(to>from,'actual collector boundary');return collector.slice(from,to);
 }
 const record=fragment('local function record(','\n-- The fixture');
 const checkpoint=fragment('local function checkpoint(','\nlocal host,root');
 function observe(from,to,replace){
  const output=[],L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  installLuaGraphObserver(L,'ABYSS_HOST_GRAPH',(label,graph)=>output.push(label+' '+graph));
  lua.lua_pushcfunction(L,L=>{output.push(to_jsstring(lua.lua_tostring(L,1)));return 0;});
  lua.lua_setglobal(L,to_luastring('print'));
  const prefix=`local events,count,hosts,nativeControls={},24,{},{}
   local F={Data={},Presentation={}};local normalizeError=function(x)return x end
   local io={stderr={write=function()end}}
   ABYSS_HOST_FULL_TRACE=true;ABYSS_HOST_FROM=${from};ABYSS_HOST_TO=${to};ABYSS_HOST_TOTAL=27
   local graph=function(value,stable)return ABYSS_HOST_GRAPH(value,{},stable)end`;
  const commands=`local child={x=1};local host={run=child};hosts[1]=host
   local co=coroutine.create(function()
    checkpoint('visible25',host,function()record('owner',host.run)end)
    checkpoint('detached26',host,function()host.run=nil;record('detached')end)
    checkpoint('returned27',host,function()host.run=${replace?'{x=1}':'child'};record('owner',host.run)end)
   end)
   local ok,tag=coroutine.resume(co);assert(ok)
   assert(ABYSS_HOST_EXECUTED==${to})
   assert(coroutine.status(co)=='dead' or tag=='HOST_WINDOW_DONE')
   assert(${to}<27 or coroutine.status(co)=='dead')`;
  const status=lauxlib.luaL_dostring(L,to_luastring([prefix,record,checkpoint,commands].join('\n')));
  assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
  assert.equal(output.filter(line=>line.startsWith('HOST_TRACE ')).length,to-from+1);
  assert.equal(output.filter(line=>line.startsWith('HOST_EVENTS ')).length,to-from+1);
  return output.join('\n');
 }
 assert.equal(observe(25,26,false),observe(25,26,true),'the first overlap never reaches the replacement');
 assert.equal(observe(26,27,false),observe(26,27,true),'the second overlap never saw the detached owner before it returned');
 assert.notEqual(observe(25,27,false),observe(25,27,true),'the original complete stream preserves long-range owner identity');
});

for(const [from,to]of resultWindows)for(const seed of [1,6])test(`whole Host result seed ${seed} boundaries ${from}-${to}`,()=>runPair({seed,from,to}));
