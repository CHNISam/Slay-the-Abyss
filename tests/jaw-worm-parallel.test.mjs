import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';

test('raw Jaw Worm tail retains all 384 rounds, 16 seeds and one rollback case within its original deadline',()=>{
 const r=runLua('tests/lua/jaw_worm_ai_slice_3.lua');
 assert.equal(r.status,0,r.stderr);
 assert.match(r.stdout,/JAW_WORM_PARALLEL_PASS 16 seeds 384 rounds/);
 assert.equal((r.stdout.match(/JAW_WORM_AI_CASE 13/g)||[]).length,1);
});

test('parallel isolation rejects changed frozen input instead of skipping assertions',async()=>{
 const {jawWormParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const source=readFileSync('tests/lua/jaw_worm_ai.lua','utf8');
 assert.equal(jawWormParts(source).length,2);
 assert.throws(()=>jawWormParts(source.replace('for _=1,24 do','for _=1,23 do')),/unreviewed/);
});

test('isolated Fengari error and complete stdout remain observable',async()=>{
 const {runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const r=await runLuaThreadParts(["print('OK_FIRST')","print('BEFORE_ERROR');error('INJECTED_LUA_FAILURE')"],{deadline:Date.now()+5000,maxBuffer:1048576});
 assert.notEqual(r.status,0);assert.match(r.stdout,/OK_FIRST/);assert.match(r.stderr,/INJECTED_LUA_FAILURE/);
});

test('one total deadline terminates a stuck worker and preserves completed peer evidence',async()=>{
 const {runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const start=Date.now();const r=await runLuaThreadParts(["print('COMPLETED_PEER')",'while true do end'],{deadline:start+1500,maxBuffer:1048576});
 assert.notEqual(r.status,0);assert.match(r.stderr,/deadline/);assert.match(r.stdout,/COMPLETED_PEER/);
 assert.ok(Date.now()-start<3500,'termination must finish, not leave a live worker');
});

test('shared output budget is bounded and overflow cannot become success',async()=>{
 const {runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const r=await runLuaThreadParts(["for i=1,1000 do print(string.rep('x',100))end","print('peer')"],{deadline:Date.now()+5000,maxBuffer:4096});
 assert.notEqual(r.status,0);assert.match(r.stderr,/output budget/);assert.ok(Buffer.byteLength(r.stdout)<=4096);
});


test('shared input guard rejects nested mutation, added fields, aliases and metatable changes',async()=>{
 const {sharedDataGuard,runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const setup="local key={value=7};local shared={enabled=false};local data={left=shared,right=shared,[key]='key'};local check=__jawSharedDataGuard(data);check();";
 for(const mutation of ["data.left.enabled=true", "data.extra=1", "data.right={enabled=false}", "key.value=8", "setmetatable(data.left,{})"]){
  const r=await runLuaThreadParts([sharedDataGuard+setup+mutation+";check()","print('independent peer')"],{deadline:Date.now()+5000,maxBuffer:1048576});
  assert.notEqual(r.status,0);assert.match(r.stderr,/shared data/);
 }
});

// Verbatim guard from e0820738331d8571c573c4f75a55a7b6344c4b38, extracted
// before the optimization. Keep this independent before-oracle unchanged.
const beforeGuard=`
function __jawSharedDataGuard(data)
 local seen,pending,records={},{data},{}
 while #pending>0 do
  local object=table.remove(pending)
  if not seen[object]then
   seen[object]=true
   local values={};local meta=getmetatable(object)
   records[#records+1]={object=object,values=values,meta=meta}
   if type(meta)=='table'then pending[#pending+1]=meta end
   for k,v in next,object do
    values[k]=v
    if type(k)=='table'then pending[#pending+1]=k end
    if type(v)=='table'then pending[#pending+1]=v end
   end
  end
 end
 return function()
  for _,record in ipairs(records)do
   assert(rawequal(getmetatable(record.object),record.meta),'shared data metatable changed')
   for k,v in next,record.values do assert(rawequal(rawget(record.object,k),v),'shared data field changed')end
   for k in next,record.object do assert(rawget(record.values,k)~=nil,'shared data field added')end
  end
 end
end
`;

test('Fengari guard matches the frozen before-oracle through raw graph mutations and restoration',async()=>{
 const {sharedDataGuard,runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const graph=`local key={value=7};local meta={tag=false};meta.self=meta
 local shared=setmetatable({enabled=false},{__eq=function()return true end})
 local data={left=shared,right=shared,[key]='key'};data.self=data;shared.owner=data
 setmetatable(key,meta)`;
 const cases=[
  ['unchanged false, aliases, cycles and metas','','',''],
  ['deleted field','data.left=nil','data.left=shared','field changed'],
  ['deleted false','shared.enabled=nil','shared.enabled=false','field changed'],
  ['same-cardinality delete/add','data.left=nil;data.extra=false','data.left=shared;data.extra=nil','field changed'],
  ['added false','data.extra=false','data.extra=nil','field added'],
  ['added true','data.extra=true','data.extra=nil','field added'],
  ['changed false','shared.enabled=true','shared.enabled=false','field changed'],
  ['changed scalar','key.value=8','key.value=7','field changed'],
  ['table-key replacement',"local other={value=7};data[key]=nil;data[other]='key'",'data[other]=nil;data[key]=\'key\'','field changed'],
  ['table-key mutation','key.value=false','key.value=7','field changed'],
  ['equal alias replacement','data.right=setmetatable({enabled=false},getmetatable(shared));assert(data.right==shared)','data.right=shared','field changed'],
  ['cycle replacement','data.self={}','data.self=data','field changed'],
  ['metatable replacement','local old=getmetatable(shared);setmetatable(shared,{__eq=old.__eq})','setmetatable(shared,old)','metatable changed'],
  ['metatable field mutation','meta.tag=true','meta.tag=false','field changed'],
  ['metatable cycle mutation','meta.self={}','meta.self=meta','field changed'],
  ['nested same-cardinality delete/add','shared.enabled=nil;shared.added=false','shared.enabled=false;shared.added=nil','field changed'],
 ];
 const program=cases.map(([name,change,restore,error],index)=>`do
 ${graph}
 local check=__jawSharedDataGuard(data);check();check()
 for attempt=1,2 do
  ${change}
  local ok,err=pcall(check)
  assert(ok==${!error},${JSON.stringify(name)})
  ${error?`assert(err:match('shared data .*$')==${JSON.stringify('shared data '+error)},err)`:''}
  ${restore}
  check()
 end
 print('GUARD_CASE ${index} ${name}')
 end`).join('\n')+`
 -- Raw observation must not invoke user equality/index/pairs/length hooks.
 local hostile={__index=function()error('INDEX_HOOK')end,__pairs=function()error('PAIRS_HOOK')end,__len=function()error('LEN_HOOK')end}
 local data=setmetatable({enabled=false},hostile);local check=__jawSharedDataGuard(data);check();check()
 data.enabled=nil;local ok,err=pcall(check);assert(not ok and err:match('shared data field changed$'),err);data.enabled=false;check()
 print('GUARD_RAW_HOOKS')
 -- Preserve the old getmetatable visibility boundary, including protected metas.
 local hidden={__metatable='locked',value=1};local data=setmetatable({},hidden)
 local check=__jawSharedDataGuard(data);check();hidden.value=2;check();hidden.value=1;check()
 local visible={value=false};local hidden={__metatable=visible};local data=setmetatable({},hidden)
 local check=__jawSharedDataGuard(data);check();visible.value=true
 local ok,err=pcall(check);assert(not ok and err:match('shared data field changed$'),err);visible.value=false;check()
 print('GUARD_PROTECTED_METAS')`;
 const r=await runLuaThreadParts([beforeGuard+program,sharedDataGuard+program],{deadline:Date.now()+5000,maxBuffer:1048576});
 assert.equal(r.status,0,r.stderr);assert.equal(r.stderr,'');
 const lines=r.stdout.trim().split(/\r?\n/);
 const expected=cases.map(([name],i)=>`GUARD_CASE ${i} ${name}`).concat('GUARD_RAW_HOOKS','GUARD_PROTECTED_METAS');
 assert.deepEqual(lines,[...expected,...expected],'both real Fengari isolates complete every mutation and restored recheck');
});

test('unchanged graph checks visit each raw field once on every call without caching results',async()=>{
 const {sharedDataGuard,runLuaThreadParts}=await import('./helpers/jaw-worm-parallel.mjs');
 const lua=sharedDataGuard+`
 local data={a=1,b=false,child={n=3}};data.self=data
 local check=__jawSharedDataGuard(data)
 local originalNext=next;local visits=0
 next=function(object,key)local k,v=originalNext(object,key);if k~=nil then visits=visits+1 end;return k,v end
 for call=1,3 do visits=0;check();assert(visits==5,'one raw-field visit per check: '..visits)end
 data.child.n=4;local ok,err=pcall(check);assert(not ok and err:match('shared data field changed$'),err)
 data.child.n=3;visits=0;check();assert(visits==5,'restored graph is checked again')
 print('GUARD_SINGLE_PASS 4 checks 5 fields')`;
 const r=await runLuaThreadParts([lua,"print('independent peer')"],{deadline:Date.now()+5000,maxBuffer:1048576});
 assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/GUARD_SINGLE_PASS 4 checks 5 fields/);
});
