import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {lua,lauxlib,to_luastring,to_jsstring}=require('fengari');
// Visit every reachable field each call. Stable mode emits changed definitions;
// preceding definitions remain part of the reconstructable graph stream.
export function installLuaGraphObserver(L,name='ABYSS_HOST_GRAPH',writeGraph){
 const allocations=new Map(),previous=new Map(),backings=new Map();let serial=0;
 const tags=Object.fromEntries([lua.LUA_TTABLE,lua.LUA_TFUNCTION,lua.LUA_TUSERDATA,lua.LUA_TTHREAD].map(type=>[type,to_jsstring(lua.lua_typename(L,type))]));
 // A graph value is a nil tag or a typed scalar/reference pair, never a table
 // body. Compare freshly collected definitions instead of encoding unchanged
 // ones just to discard them. No Lua fields, aliases or metatables are cached.
 const sameValue=(a,b)=>a===b||(a!==null&&b!==null&&a.length===b.length&&a[0]===b[0]&&a[1]===b[1]);
 const sameDefinition=(a,b)=>{
  if(!a||a[0]!==b[0]||a[1]!==b[1]||!sameValue(a[3],b[3])||a[2].length!==b[2].length)return false;
  for(let i=0;i<a[2].length;i++)if(!sameValue(a[2][i][0],b[2][i][0])||!sameValue(a[2][i][1],b[2][i][1]))return false;
  return true;
 };
 const observe=(L,eventArgs=false)=>{
  const stable=eventArgs||lua.lua_toboolean(L,3),localIds=new Map(),visited=new Set(),definitions=[],proxies=new Map();let localSerial=0;
  const event=eventArgs||lua.lua_toboolean(L,4);
  function identity(pointer){const ids=stable?allocations:localIds;let id=ids.get(pointer);
   if(id===undefined){id=stable?++serial:++localSerial;ids.set(pointer,id);}return id;}
  function capture(index){const type=lua.lua_type(L,index);
   if(type===lua.LUA_TNIL)return ['nil'];
   if(type===lua.LUA_TBOOLEAN)return ['boolean',lua.lua_toboolean(L,index)];
   if(type===lua.LUA_TNUMBER)return ['number',String(lua.lua_tonumber(L,index))];
   if(type===lua.LUA_TSTRING)return ['string',to_jsstring(lua.lua_tolstring(L,index))];
   // Reuse only a typed reference-push closure within this call. Every field,
   // metatable and definition is still freshly visited; IDs are assigned by read.
   let typed=proxies.get(type);if(!typed){typed=new Map();proxies.set(type,typed);}
   const pointer=lua.lua_topointer(L,index);let push=typed.get(pointer);
   if(!push){push=lua.lua_toproxy(L,index);typed.set(pointer,push);}
   return push;
  }
  function captured(value){if(typeof value!=='function')return value;value(L);const result=read(-1);lua.lua_pop(L,1);return result;}
  function read(index){
   if(!lua.lua_checkstack(L,12))throw Error('observer stack exhausted');
   index=lua.lua_absindex(L,index);const originalIndex=index,type=lua.lua_type(L,index);
   if(type===lua.LUA_TNIL)return ['nil'];
   if(type===lua.LUA_TBOOLEAN)return ['boolean',lua.lua_toboolean(L,index)];
   if(type===lua.LUA_TNUMBER)return ['number',String(lua.lua_tonumber(L,index))];
   if(type===lua.LUA_TSTRING)return ['string',to_jsstring(lua.lua_tolstring(L,index))];
   const tag=tags[type];if(tag===undefined)throw Error('unsupported graph value');
   const pointer=lua.lua_topointer(L,index),id=identity(pointer);
   if(event&&type===lua.LUA_TTABLE&&backings.has(pointer))return ['nativeControl',id];
   if(visited.has(id))return [tag,id];visited.add(id);const entries=[];
   if(type===lua.LUA_TTABLE){
    // Native proxy controls retain their full engine backing fields here.
    const backing=backings.get(pointer);
    if(backing){backing(L);index=lua.lua_absindex(L,-1);}
    const keys=[];lua.lua_pushnil(L);
    while(lua.lua_next(L,index)){
     const key=capture(-2),value=capture(-1),kt=lua.lua_type(L,-2);let order;
     if(kt===lua.LUA_TSTRING)order='string:'+key[1];
     else if(kt===lua.LUA_TNUMBER)order='number:'+lua.lua_tonumber(L,-2);
     else if(kt===lua.LUA_TBOOLEAN)order='boolean:'+lua.lua_toboolean(L,-2);
     else order=to_jsstring(lua.lua_typename(L,kt))+':'+identity(lua.lua_topointer(L,-2));
     keys.push({key,value,order});lua.lua_pop(L,1);
    }
    keys.sort((a,b)=>a.order<b.order?-1:a.order>b.order?1:0);
    for(const key of keys)entries.push([captured(key.key),captured(key.value)]);
    if(backing){lua.lua_pop(L,1);index=originalIndex;
     for(const field of ['alive','activeInHierarchy']){lua.lua_getfield(L,index,to_luastring(field));entries.push([['engine',field],read(-1)]);lua.lua_pop(L,1);}
    }
   }
   const hasMeta=lua.lua_getmetatable(L,index),meta=hasMeta?read(-1):null;if(hasMeta)lua.lua_pop(L,1);
   const definition=[tag,id,entries,meta];
   if(!stable||!sameDefinition(previous.get(id),definition)){definitions.push(definition);if(stable)previous.set(id,definition);}
   return [tag,id];
  }
  let root;
  if(eventArgs){root=[];const n=lua.lua_gettop(L);for(let i=1;i<=n;i++)root.push(read(i));}
  else if(event){
   lua.lua_getfield(L,1,to_luastring('n'));const n=lua.lua_tonumber(L,-1);lua.lua_pop(L,1);root=[];
   for(let i=1;i<=n;i++){lua.lua_rawgeti(L,1,i);root.push(read(-1));lua.lua_pop(L,1);}
  }else root=read(1);
  definitions.sort((a,b)=>a[1]-b[1]);
  return JSON.stringify({root,definitions});
 };
 const returned=(L,eventArgs=false)=>{lua.lua_pushstring(L,to_luastring(observe(L,eventArgs)));return 1;};
 lua.lua_pushcfunction(L,L=>returned(L));lua.lua_setglobal(L,to_luastring(name));
 lua.lua_pushcfunction(L,L=>returned(L,true));lua.lua_setglobal(L,to_luastring(name+'_EVENT'));
 // The same fresh serializer can emit a large checkpoint without converting its
 // complete JSON string to Lua bytes and back. The caller owns the bounded sink.
 if(writeGraph){
  lua.lua_pushcfunction(L,L=>{const label=to_jsstring(lauxlib.luaL_checkstring(L,2));writeGraph(label,observe(L));return 0;});
  lua.lua_setglobal(L,to_luastring(name+'_WRITE'));
 }
 lua.lua_pushcfunction(L,L=>{backings.set(lua.lua_topointer(L,1),lua.lua_toproxy(L,2));return 0;});
 lua.lua_setglobal(L,to_luastring(name+'_CONTROL'));
}
