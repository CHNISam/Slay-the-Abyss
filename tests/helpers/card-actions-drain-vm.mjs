// Fresh Fengari process. Native graph observation avoids repeated Lua string
// construction; every snapshot traverses every reachable table, emitting full
// replacement definitions for changed nodes. Readers retain unchanged nodes.
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const identities=new Map(),previous=new Map();let serial=0;
lua.lua_pushcfunction(L,L=>{
  const visited=new Set(),nodes=[];
  const identity=index=>{
    const pointer=lua.lua_topointer(L,index);
    if(!identities.has(pointer))identities.set(pointer,++serial);
    return identities.get(pointer);
  };
  const read=index=>{
    index=lua.lua_absindex(L,index);const type=lua.lua_type(L,index);
    if(type===lua.LUA_TNIL)return ['nil','nil'];
    if(type===lua.LUA_TBOOLEAN)return ['boolean',String(lua.lua_toboolean(L,index))];
    if(type===lua.LUA_TNUMBER)return ['number',String(lua.lua_tonumber(L,index))];
    if(type===lua.LUA_TSTRING)return ['string',to_jsstring(lua.lua_tolstring(L,index))];
    if(type===lua.LUA_TFUNCTION)return ['function',identity(index)];
    if(type!==lua.LUA_TTABLE)throw Error(`unsupported graph value ${lua.lua_typename(L,type)}`);
    const id=identity(index);
    if(visited.has(id))return ['table',id];
    visited.add(id);
    const keys=[];lua.lua_pushnil(L);
    while(lua.lua_next(L,index)){
      const kind=lua.lua_type(L,-2);
      const key=kind===lua.LUA_TSTRING?['string',to_jsstring(lua.lua_tolstring(L,-2))]
        :kind===lua.LUA_TNUMBER?['number',String(lua.lua_tonumber(L,-2))]
        :kind===lua.LUA_TBOOLEAN?['boolean',String(lua.lua_toboolean(L,-2))]
        :kind===lua.LUA_TTABLE?['table',identity(-2)]
        :kind===lua.LUA_TFUNCTION?['function',identity(-2)]:null;
      if(!key)throw Error('unsupported graph key');
      keys.push({sort:key[0]+key[1],push:lua.lua_toproxy(L,-2)});
      lua.lua_pop(L,1);
    }
    keys.sort((a,b)=>a.sort<b.sort?-1:a.sort>b.sort?1:0);
    const fields=[];
    for(const key of keys){
      key.push(L);const encodedKey=read(-1);lua.lua_rawget(L,index);fields.push([encodedKey,read(-1)]);lua.lua_pop(L,1);
    }
    let metatable=['nil','nil'];
    if(lua.lua_getmetatable(L,index)){metatable=read(-1);lua.lua_pop(L,1);}
    const definition=JSON.stringify([fields,metatable]);
    if(previous.get(id)!==definition){previous.set(id,definition);nodes.push([id,fields,metatable]);}
    return ['table',id];
  };
  const root=read(1);lua.lua_pushstring(L,to_luastring(JSON.stringify({root,nodes})));return 1;
});lua.lua_setglobal(L,to_luastring('ABYSS_DRAIN_GRAPH'));
const source=`dofile(${JSON.stringify(process.argv[2].replaceAll('\\','/'))})`;
if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exitCode=1;}
