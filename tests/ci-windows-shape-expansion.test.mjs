import {beforeExecutionTimeoutWorkflow} from './helpers/auto-merge-workflow.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {ciWindowsShapeProof as proof,preCiWindowsShapeSource} from './helpers/ci-windows-shape-source-inverse.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {ciCompleteCalibrationProof,preCiCompleteCalibrationSource} from './helpers/ci-complete-calibration-source-inverse.mjs';
import {discoverJs,partition} from '../scripts/ci-shards.mjs';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const {qualityShardMatrices,qualityShardJobs}=await import('data:text/javascript,'+encodeURIComponent(proof.afterSource));
const historicalFullQualityJobs=['check','presentation','engineering-posix',...qualityShardJobs,'impact','fast'];
const timings=JSON.parse(preCiCompleteCalibrationSource('scripts/ci-test-timings.json',readFileSync('scripts/ci-test-timings.json','utf8')));
const jsShard=(files,value,platform)=>partition(files,value,Object.fromEntries(files.map(file=>[file,Math.max(timings.js[platform][file]??timings.unknownJsMs,timings.jsPlanning?.localLowerBounds?.[file]?.durationMs??0)])),timings.unknownJsMs,Array.from({length:Number(value.split('/')[1])},(_,i)=>i===0?timings.initialMs[platform][0]:0));

test('TASK-75.5 historical thirteen-to-fourteen source and exact 28-job shape remain intact behind the approved outer epoch',()=>{
 const actual=preCiCompleteCalibrationSource(proof.path,readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'));
 assert.equal(actual,proof.afterSource,'projected complete source must retain the approved historical fourteen-shard epoch');
 assert.equal(actual,proof.beforeSource.replace('length:13','length:14'),'one exact production edit');
 assert.deepEqual(qualityShardMatrices.windows,[1,2,3,4,5,6,7,8,9,10,11,12,13,14]);
 assert.deepEqual(qualityShardMatrices.posix,[1,2,3,4,5,6,7,8,9]);
 assert.deepEqual(historicalFullQualityJobs,['check','presentation','engineering-posix',
  ...Array.from({length:14},(_,i)=>`rules (${i+1}/14)`),...Array.from({length:9},(_,i)=>`engineering-posix (${i+1}/9)`),'impact','fast']);
 assert.equal(historicalFullQualityJobs.length,28);assert.equal(new Set(historicalFullQualityJobs).size,28);
 assert.equal(qualityShardJobs.length,23);
 const workflow=beforeExecutionTimeoutWorkflow(readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n'));
 assert.match(workflow,/^      max-parallel: 12$/m,'the approved current POSIX concurrency cap remains outside the historical shape projection');
 assert.match(workflow,/timeout-minutes: 20/);assert.match(workflow,/local-special' && 75 \|\| 30/);
 for(const source of ['scripts/ci-impact.mjs','scripts/verify-delivery.mjs'])assert.ok(readFileSync(source,'utf8').includes("from './ci-quality-shape.mjs'"));
});

test('complete approved fourteen-shard source alone recovers the unchanged full historical thirteen-shard source',()=>{
 assert.equal(proof.beforeSha256,'7c36fe94241ad5002860f7b09592979db5af45f6632732890c7b773ceeaea2a6');
 assert.equal(proof.beforeGitBlob,'a9bf7b25667bdf06c0dfb28e3992a379f12f2576');
 for(const source of [proof.afterSource,proof.afterSource.replaceAll('\n','\r\n')]){
  assert.equal(preCiWindowsShapeSource(proof.path,source),proof.beforeSource);
  assert.equal(preIntegrationSource(proof.path,source,'base',{readSource(){assert.fail('shape inverse has no linked owner');}}),proof.beforeSource);
 }
 for(const value of [proof.beforeSource,null,{},undefined])assert.equal(preCiWindowsShapeSource(proof.path,value),value);
 for(const source of [proof.afterSource+'\n',proof.afterSource.replace('length:14','length:13'),proof.afterSource.replace('length:14','length:15'),
  proof.afterSource.replace('length:9','length:8'),proof.afterSource.replace('  posix:', '  windows:Object.freeze([14]),\n  posix:'),proof.afterSource.slice(0,-20)]){
  assert.notEqual(source,proof.afterSource);assert.equal(preCiWindowsShapeSource(proof.path,source),source);
  if(source!==proof.beforeSource)assert.notEqual(hash(preCiWindowsShapeSource(proof.path,source)),proof.beforeSha256);
 }
 assert.equal(preCiWindowsShapeSource('scripts/foreign.mjs',proof.afterSource),proof.afterSource);
});

test('historical fourteen-slot budget retains its complete observed inventory while partition coverage includes every current file',()=>{
 const js=discoverJs(),lua=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 for(const [platform,count]of [['win32',14],['linux',9]]){
  const bins=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files),union=bins.flat();
  assert.equal(new Set(union).size,union.length);assert.deepEqual(union.sort(),[...js].sort());
 }
 const short=file=>(timings.lua[file]??timings.unknownLuaMs)<10000;
 function combined(count,jsFiles,luaFiles){
  const jsLoads=jsShard(jsFiles,`1/${count}`,'win32').loads;
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(luaFiles,`${i+1}/${count}`,{...timings,windowsJsShardMs:jsLoads},2));
  assert.equal(new Set(bins.flat()).size,luaFiles.length);assert.deepEqual(bins.flat().sort(),[...luaFiles].sort());
  const observed=file=>timings.luaShard[file]??timings.lua[file]??timings.unknownLuaMs;
  return bins.map((bin,i)=>{
   const pool=[0,0];
   for(const file of bin.filter(short).sort((a,b)=>(timings.lua[b]??timings.unknownLuaMs)-(timings.lua[a]??timings.unknownLuaMs)||a.localeCompare(b)))pool[pool[0]<=pool[1]?0:1]+=observed(file);
   return jsLoads[i]+bin.filter(file=>!short(file)).reduce((sum,file)=>sum+observed(file),0)+Math.max(...pool);
  });
 }
 // The sealed observations identify the complete inventory of the historical
 // fourteen-slot epoch. Later unknown files belong to the current Full
 // budget in ci-complete-calibration.test.mjs, not to this old capacity witness.
 const historicalJs=[...new Set(ciCompleteCalibrationProof.evidence.observations.js.map(row=>row.file))].sort();
 const historicalLua=[...new Set(ciCompleteCalibrationProof.evidence.observations.lua.map(row=>row.file))].sort();
 assert.equal(historicalJs.length,725);assert.equal(historicalLua.length,1356);
 for(const file of historicalJs)assert(js.includes(file),'complete historical JS input still present: '+file);
 for(const file of historicalLua)assert(lua.includes(file),'complete historical Lua input still present: '+file);
 combined(13,js,lua);combined(14,js,lua); // Current raw inventory keeps both complete partition checks.
 assert.ok(Math.max(...combined(13,historicalJs,historicalLua))+60000>=1800000,'retain the actual thirteen-slot infeasibility witness');
 assert.ok(Math.max(...combined(14,historicalJs,historicalLua))+60000<1800000,'the unchanged thirty-minute budget and sixty-second sensitivity must pass');
 const posix=Array.from({length:9},(_,i)=>shardLuaScripts(lua,`${i+1}/9`,timings,2));
 assert.equal(new Set(posix.flat()).size,lua.length);assert.deepEqual(posix.flat().sort(),[...lua].sort());
});
