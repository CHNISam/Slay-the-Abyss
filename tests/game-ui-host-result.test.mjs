import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
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

test('fresh graph deltas preserve the fixed original observer stream across every value and entry mode',()=>{
 // Oracle: tests/helpers/lua-graph-observer.mjs at 67793786, SHA256
 // ddef991a2c414dcf6838cc9d343fa99269ae9d9c297368b3ac8df46cd785fa15.
 // This fixed digest comes from that unmodified observer, not from the candidate.
 function observe(nativeWrite){
  const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
  const output=[],L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  lua.lua_newuserdata(L,1);lua.lua_setglobal(L,to_luastring('probeUserdata'));
  installLuaGraphObserver(L,'ABYSS_HOST_GRAPH',(label,graph)=>output.push(label+' '+graph+'\n'));
  lua.lua_pushcfunction(L,L=>{output.push(to_jsstring(lua.lua_tostring(L,1))+'\n');return 0;});lua.lua_setglobal(L,to_luastring('print'));
  lua.lua_pushcfunction(L,L=>{lua.lua_getglobal(L,to_luastring('probeString'));lua.lua_tolstring(L,-1)[0]=lua.lua_tointeger(L,1);lua.lua_pop(L,1);return 0;});lua.lua_setglobal(L,to_luastring('mutateBytes'));
  const source=`local function emit(label,value,stable,event)
    ${nativeWrite?'ABYSS_HOST_GRAPH_WRITE(value,label,stable,event)':'print(label.." "..ABYSS_HOST_GRAPH(value,{},stable,event))'}
   end
   probeString='red';local child={value='中文\\0😀',bytes=probeString,flag=false,inf=math.huge,nan=0/0,empty=''}
   local key={};local fn=function()end;local thread=coroutine.create(function()end)
   local meta={__index={value='meta'}}
   local root=setmetatable({first=child,second=child,[key]=key,[true]=false,[false]=true,[fn]=fn,[thread]=thread,[probeUserdata]=probeUserdata,[math.sin]=math.sin,[0]='zero',[-1]='negative'},meta)
   root.self=root;root.fn=fn;root.thread=thread;root.userdata=probeUserdata
   debug.setmetatable(probeUserdata,{value='userdata meta'});debug.setmetatable(fn,{value='function meta'});debug.setmetatable(thread,{value='thread meta'})
   local alive,active=true,true
   local control=setmetatable({},{__index=function(_,field)if field=='alive'then return alive elseif field=='activeInHierarchy'then return active end end})
   local backing={nested=child};ABYSS_HOST_GRAPH_CONTROL(control,backing);root.control=control
   emit('plain',root,false);emit('first',root,true);emit('unchanged',root,true)
   child.value='value only';emit('value-only',root,true)
   child.rename='same';emit('before-key-only',root,true);child.renamed=child.rename;child.rename=nil;emit('key-only',root,true)
   setmetatable(root,{__index={value='replacement meta'}});emit('meta-only',root,true);setmetatable(root,meta);emit('meta-restored',root,true)
   root.second={value=child.value};emit('alias-only',root,true);root.second=child;emit('alias-restored',root,true)
   print('event '..ABYSS_HOST_GRAPH_EVENT('native',control,nil,child,false,nil))
   emit('packed',table.pack(control,nil,child,false,nil),true,true)
   child.value='changed';child.flag=nil;child.added=true;mutateBytes(string.byte('b'));meta.__index.value='changed meta'
   debug.getmetatable(probeUserdata).value='changed userdata';debug.getmetatable(fn).value='changed function';debug.getmetatable(thread).value='changed thread'
   alive=false;active=false;backing.extra='backing added';emit('mutated',root,true)
   root.second={value=child.value};root.fn=function()end;root[key]=nil;root[fn]=nil;root[math.sin]=math.cos;setmetatable(root,nil)
   emit('split',root,true)
   root.first=nil;root.second=nil;backing.nested=nil;emit('detached',root,true)
   child.value='中文\\0😀';mutateBytes(string.byte('r'));root.first=child;root.second=child;backing.nested=child;backing.extra=nil
   setmetatable(root,meta);emit('restored',root,true);emit('unchanged2',root,true)
   emit('plain2',root,false);emit('stable-after-plain',root,true);emit('nil',nil,true)
   print('arity '..ABYSS_HOST_GRAPH_EVENT(nil,false,nil))`;
  const status=lauxlib.luaL_dostring(L,to_luastring(source));assert.equal(status,lua.LUA_OK);
  return output.join('');
 }
 for(const nativeWrite of [false,true]){
  const stream=observe(nativeWrite);
  assert.equal(Buffer.byteLength(stream),11962);
  assert.equal(createHash('sha256').update(stream).digest('hex'),'0e838aea2f09440f61e7fdf07d3c026a6a48aa42c14c4595d6719576f4d5917e');
 }
});

test('graph strings still reject invalid UTF-8 after a previously observed buffer changes',()=>{
 const {lua,lauxlib,lualib,to_luastring}=require('fengari');
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);installLuaGraphObserver(L);
 assert.equal(lauxlib.luaL_dostring(L,to_luastring("probe='red';return ABYSS_HOST_GRAPH({value=probe},{},true)")),lua.LUA_OK);
 lua.lua_settop(L,0);lua.lua_getglobal(L,to_luastring('probe'));
 lua.lua_tolstring(L,-1)[0]=255;lua.lua_pop(L,1);
 assert.notEqual(lauxlib.luaL_dostring(L,to_luastring('return ABYSS_HOST_GRAPH({value=probe},{},true)')),lua.LUA_OK);
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
