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
