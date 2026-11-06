import test from 'node:test';
import assert from 'node:assert/strict';
import {phases,counters,validateSample,percentile} from '../scripts/benchmark-runtime-path.mjs';
function sample(){
 const rows=phases.map(phase=>({phase,elapsedMs:1,...Object.fromEntries(counters.map(key=>[key,0])),memory:{rss:100,heapUsed:50}}));
 Object.assign(rows[1],{moduleLoads:2,nativeCalls:3,propertyWrites:4});rows[5].snapshots=1;
 return {rows};
}
test('runtime baseline requires the complete ordered path and every observer',()=>{
 assert.equal(validateSample(sample()).rows.length,11);
 for(const change of [s=>s.rows.pop(),s=>s.rows.reverse(),s=>s.rows[1].moduleLoads=0,s=>s.rows[2].moduleLoads=1,
  s=>s.rows.forEach(r=>r.nativeCalls=0),s=>s.rows.forEach(r=>r.propertyWrites=0),s=>s.rows.forEach(r=>r.snapshots=0)]){
  const s=sample();change(s);assert.throws(()=>validateSample(s));
 }
});
test('runtime baseline rejects invalid timings, counts and memory instead of inventing zeros',()=>{
 for(const change of [s=>s.rows[0].elapsedMs=NaN,s=>s.rows[0].elapsedMs=-1,s=>s.rows[0].snapshots=.5,
  s=>delete s.rows[0].requireCalls,s=>s.rows[0].memory.rss=0]){
  const s=sample();change(s);assert.throws(()=>validateSample(s));
 }
});
test('three-sample nearest-rank percentiles retain slowest P95 and do not mutate inputs',()=>{
 const values=[9,1,5];assert.equal(percentile(values,.5),5);assert.equal(percentile(values,.95),9);
 assert.deepEqual(values,[9,1,5]);assert.throws(()=>percentile([],.95));assert.throws(()=>percentile([NaN],.95));
});
test('native observer preserves capability, read-only, argument and callback semantics',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const result=runLua('scripts/runtime-baseline/observer-check.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/RUNTIME_OBSERVER_PASS/);
});
test('runtime turn contract rejects no-op, skipped and unfinished combat transitions',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const result=runLua('scripts/runtime-baseline/turn-check.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/RUNTIME_TURN_CONTRACT_PASS/);
});
