import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {installLuaGraphObserver} from './helpers/lua-graph-observer.mjs';
import {runPair,mutateSource} from './helpers/game-ui-host-equivalence.mjs';
const require=createRequire(import.meta.url);
test('full graph observer rejects alias split/merge, RNG limb and return arity changes',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 function observe(body){const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);installLuaGraphObserver(L);
  assert.equal(lauxlib.luaL_dostring(L,to_luastring(`local v=(function()${body}\nend)();return ABYSS_HOST_GRAPH(v,{},false)`)),lua.LUA_OK);
  return to_jsstring(lua.lua_tostring(L,-1));}
 assert.notEqual(observe('local t={x=1};return {a=t,b=t}'),observe('return {a={x=1},b={x=1}}'));
 assert.notEqual(observe('return {a={x=1},b={x=1}}'),observe('local t={x=1};return {a=t,b=t}'));
 assert.notEqual(observe('return {rng={1,2,3,4}}'),observe('return {rng={1,2,3,5}}'));
 assert.notEqual(observe('return table.pack(true,nil)'),observe('return table.pack(true)'));
 assert.notEqual(observe('return {x=false}'),observe('return {x="false"}'));
 assert.equal(observe('local t={};t.self=t;return t'),observe('local t={};t.self=t;return t'));
 assert.notEqual(observe('local f=function()end;return {a=f,b=f}'),observe('return {a=function()end,b=function()end}'));
 assert.notEqual(observe('return setmetatable({},{__index={x=1}})'),observe('return setmetatable({},{__index={x=2}})'));
 assert.notEqual(observe('local k={x=1};return {[k]=k,[true]=1}'),observe('local k={x=2};return {[k]=k,[true]=1}'));
 assert.notEqual(observe('return {native={argument={nested={x=1}}}}'),observe('return {native={argument={nested={x=2}}}}'));
 const restored=JSON.parse(observe(`local child={x=1};local parent={child=child};local marked={[child]=1,[parent]=2};
  local a=ABYSS_HOST_GRAPH(parent,marked,true);child.x=2;local b=ABYSS_HOST_GRAPH(parent,marked,true);
  child.x=1;local c=ABYSS_HOST_GRAPH(parent,marked,true);return {a,b,c}`));
 const values=restored.definitions.find(node=>node[0]==='table')[2].map(entry=>entry[1][1]);
 assert.equal(values.length,3);assert.notEqual(values[0],values[1]);assert.notEqual(values[1],values[2]);
 assert.match(values[1],/"x".*"2"/);assert.match(values[2],/"x".*"1"/);
 const native=JSON.parse(observe(`local control=setmetatable({},{__index={alive=true,activeInHierarchy=true}});
  local backing={x=1};ABYSS_HOST_GRAPH_CONTROL(control,backing);
  local a=ABYSS_HOST_GRAPH(table.pack({nested=control}),{},true,true);
  local b=ABYSS_HOST_GRAPH(control,{},true);backing.x=2;
  local c=ABYSS_HOST_GRAPH(control,{},true);return {a,b,c}`));
 const nativeValues=native.definitions.find(node=>node[0]==='table')[2].map(entry=>entry[1][1]);
 assert.match(nativeValues[0],/nativeControl/);assert.match(nativeValues[1],/"x".*"1"/);
 assert.match(nativeValues[2],/"x".*"2"/);
});

for(const [name,module,before,after,from,to]of [
 ['nil settlement acceptance','run','accepted == false','not accepted',28,30],
 ['cleanup pending retry','lifecycle','self.monsterCleanupPending=not released or nil','self.monsterCleanupPending=nil',31,35],
 ['pointer ownership','input','observed or cursor.CursorDown and cursor.CursorUp and touch(event) ~= nil','false',1,6],
])test(`whole Host parsed semantic negative control: ${name}`,()=>runPair({seed:1,from,to},dir=>mutateSource(dir,module,before,after)));
