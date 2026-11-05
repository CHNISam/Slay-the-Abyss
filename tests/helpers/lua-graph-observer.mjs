import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {lua,lauxlib,to_luastring,to_jsstring}=require('fengari');
// Visit every reachable field each call. Stable mode emits changed definitions;
// preceding definitions remain part of the reconstructable graph stream.
export function installLuaGraphObserver(L,name='ABYSS_HOST_GRAPH'){
 const allocations=new Map(),previous=new Map(),backings=new Map();let serial=0;
 const observe=(L,eventArgs=false)=>{
  const stable=eventArgs||lua.lua_toboolean(L,3),localIds=new Map(),visited=new Set(),definitions=[];let localSerial=0;
  const event=eventArgs||lua.lua_toboolean(L,4);
  function identity(index){const pointer=lua.lua_topointer(L,index),ids=stable?allocations:localIds;
   if(!ids.has(pointer))ids.set(pointer,stable?++serial:++localSerial);return ids.get(pointer);}
  function capture(index){const type=lua.lua_type(L,index);
   if(type===lua.LUA_TNIL)return {value:['nil']};
   if(type===lua.LUA_TBOOLEAN)return {value:['boolean',lua.lua_toboolean(L,index)]};
   if(type===lua.LUA_TNUMBER)return {value:['number',String(lua.lua_tonumber(L,index))]};
   if(type===lua.LUA_TSTRING)return {value:['string',to_jsstring(lua.lua_tolstring(L,index))]};
   return {push:lua.lua_toproxy(L,index)};
  }
  function captured(value){if(value.value)return value.value;value.push(L);const result=read(-1);lua.lua_pop(L,1);return result;}
  function read(index){
   if(!lua.lua_checkstack(L,12))throw Error('observer stack exhausted');
   index=lua.lua_absindex(L,index);const originalIndex=index,type=lua.lua_type(L,index);
   if(type===lua.LUA_TNIL)return ['nil'];
   if(type===lua.LUA_TBOOLEAN)return ['boolean',lua.lua_toboolean(L,index)];
   if(type===lua.LUA_TNUMBER)return ['number',String(lua.lua_tonumber(L,index))];
   if(type===lua.LUA_TSTRING)return ['string',to_jsstring(lua.lua_tolstring(L,index))];
   if(![lua.LUA_TTABLE,lua.LUA_TFUNCTION,lua.LUA_TUSERDATA,lua.LUA_TTHREAD].includes(type))throw Error('unsupported graph value');
   const id=identity(index),tag=to_jsstring(lua.lua_typename(L,type));
   if(event&&type===lua.LUA_TTABLE&&backings.has(lua.lua_topointer(L,index)))return ['nativeControl',id];
   if(visited.has(id))return [tag,id];visited.add(id);const entries=[];
   if(type===lua.LUA_TTABLE){
    // Native proxy controls retain their full engine backing fields here.
    const backing=backings.get(lua.lua_topointer(L,index));
    if(backing){backing(L);index=lua.lua_absindex(L,-1);}
    const keys=[];lua.lua_pushnil(L);
    while(lua.lua_next(L,index)){
     const key=capture(-2),value=capture(-1),kt=lua.lua_type(L,-2);let order;
     if(kt===lua.LUA_TSTRING)order='string:'+to_jsstring(lua.lua_tolstring(L,-2));
     else if(kt===lua.LUA_TNUMBER)order='number:'+lua.lua_tonumber(L,-2);
     else if(kt===lua.LUA_TBOOLEAN)order='boolean:'+lua.lua_toboolean(L,-2);
     else order=to_jsstring(lua.lua_typename(L,kt))+':'+identity(-2);
     keys.push({key,value,order});lua.lua_pop(L,1);
    }
    keys.sort((a,b)=>a.order<b.order?-1:a.order>b.order?1:0);
    for(const key of keys)entries.push([captured(key.key),captured(key.value)]);
    if(backing){lua.lua_pop(L,1);index=originalIndex;
     for(const field of ['alive','activeInHierarchy']){lua.lua_getfield(L,index,to_luastring(field));entries.push([['engine',field],read(-1)]);lua.lua_pop(L,1);}
    }
   }
   const hasMeta=lua.lua_getmetatable(L,index),meta=hasMeta?read(-1):null;if(hasMeta)lua.lua_pop(L,1);
   const definition=[tag,id,entries,meta],encoded=JSON.stringify(definition);
   if(!stable||previous.get(id)!==encoded){definitions.push(definition);if(stable)previous.set(id,encoded);}
   return [tag,id];
  }
  let root;
  if(eventArgs){root=[];const n=lua.lua_gettop(L);for(let i=1;i<=n;i++)root.push(read(i));}
  else if(event){
   lua.lua_getfield(L,1,to_luastring('n'));const n=lua.lua_tonumber(L,-1);lua.lua_pop(L,1);root=[];
   for(let i=1;i<=n;i++){lua.lua_rawgeti(L,1,i);root.push(read(-1));lua.lua_pop(L,1);}
  }else root=read(1);
  definitions.sort((a,b)=>a[1]-b[1]);
  lua.lua_pushstring(L,to_luastring(JSON.stringify({root,definitions})));return 1;
 };
 lua.lua_pushcfunction(L,L=>observe(L));lua.lua_setglobal(L,to_luastring(name));
 lua.lua_pushcfunction(L,L=>observe(L,true));lua.lua_setglobal(L,to_luastring(name+'_EVENT'));
 lua.lua_pushcfunction(L,L=>{backings.set(lua.lua_topointer(L,1),lua.lua_toproxy(L,2));return 0;});
 lua.lua_setglobal(L,to_luastring(name+'_CONTROL'));
}
