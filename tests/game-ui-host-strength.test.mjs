import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdtempSync,mkdirSync,writeFileSync,realpathSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,dirname,basename} from 'node:path';
import {spawnSync} from 'node:child_process';
import {installLuaGraphObserver} from './helpers/lua-graph-observer.mjs';
import {runPair,mutateSource} from './helpers/game-ui-host-equivalence.mjs';
const require=createRequire(import.meta.url);

test('the final Host window cannot silently omit extra commands',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-host-driver-')),expected=realpathSync(directory),parent=realpathSync(tmpdir());
 try{
  mkdirSync(join(directory,'tests/lua/support'),{recursive:true});
  const driver=resolve('tests/helpers/game-ui-host-vm.mjs');
  for(const [scenario,body,status]of [
   ['contract','ABYSS_HOST_EXECUTED=1',0],
   ['','ABYSS_HOST_EXECUTED=1;coroutine.yield("HOST_WINDOW_DONE");ABYSS_HOST_EXECUTED=2',0],
   ['contract','ABYSS_HOST_EXECUTED=1;coroutine.yield("HOST_WINDOW_DONE");ABYSS_HOST_EXECUTED=2',1],
  ]){
   writeFileSync(join(directory,'tests/lua/support/game_ui_host_trace.lua'),body);
   const result=spawnSync(process.execPath,[driver,'1',scenario,'1','1'],{cwd:directory,encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
   assert.ifError(result.error);assert.equal(result.status,status,result.stderr);
   if(status)assert.match(result.stderr,/declared total leaves unexecuted commands/);
  }
 }finally{
  const target=realpathSync(directory);assert.equal(target,expected);assert.equal(dirname(target),parent);assert.ok(basename(target).startsWith('abyss-host-driver-'));
  rmSync(target,{recursive:true,force:true});
 }
});
test('Host error observer removes only known source-root coordinates',()=>{
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const status=lauxlib.luaL_dostring(L,to_luastring(`local normalize=dofile('tests/lua/support/game_ui_host_errors.lua')
  local message='business reason foo.lua:12: final'
  local ok,why=pcall(function()error(message,0)end)
  assert(not ok and normalize(why)==message)
  assert(normalize('./src/lua/abyss_game_ui.lua:31: ./src/lua/abyss_game_ui_run.lua:22: '..message)==message)
  assert(normalize('unexpected.lua:12: final')=='unexpected.lua:12: final')
  assert(normalize('./other/semantic.lua:12: final')=='./other/semantic.lua:12: final')
  local identity={};assert(normalize(identity)==identity)`));
 assert.equal(status,lua.LUA_OK,status===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
});
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

for(const [name,module,before,after,from,to,secondBefore,secondAfter]of [
 ['nil settlement acceptance','run','accepted == false','not accepted',30,30],
 ['cleanup pending retry','lifecycle','self.monsterCleanupPending=not released or nil','self.monsterCleanupPending=nil',33,33],
 ['pointer ownership','input','observed or cursor.CursorDown and cursor.CursorUp and touch(event) ~= nil','false',5,5],
 ['cancel before inert','lifecycle','self.battleUI.active=false','do end',7,7,'self.battleUI.feedback:cancel()','self.battleUI.feedback:cancel();self.battleUI.active=false'],
])test(`whole Host parsed semantic negative control: ${name}`,()=>runPair({seed:1,from,to,...(name==='cancel before inert'?{
 scenario:'short-disable-live',requiredBaselineMarker:'HOST_DISABLE_LIVE_INERT_PASS',expectedMutantMarker:'HOST_CANCEL_MUST_BE_INERT'}:{})},dir=>{
 mutateSource(dir,module,before,after);if(secondBefore)mutateSource(dir,module,secondBefore,secondAfter);
}));
