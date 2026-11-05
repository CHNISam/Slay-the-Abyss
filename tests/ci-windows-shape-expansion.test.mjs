import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {ciWindowsShapeProof as proof,preCiWindowsShapeSource} from './helpers/ci-windows-shape-source-inverse.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {qualityShardMatrices,qualityShardJobs} from '../scripts/ci-quality-shape.mjs';
import {currentFullQualityJobs} from '../scripts/verify-delivery.mjs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');

test('TASK-75.5 changes only the shared Windows shape from thirteen to fourteen and current Full has exactly 28 jobs',()=>{
 const actual=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n');
 assert.equal(actual,proof.afterSource,'physical current source must be the approved fourteen-shard epoch');
 assert.equal(actual,proof.beforeSource.replace('length:13','length:14'),'one exact production edit');
 assert.deepEqual(qualityShardMatrices.windows,[1,2,3,4,5,6,7,8,9,10,11,12,13,14]);
 assert.deepEqual(qualityShardMatrices.posix,[1,2,3,4,5,6,7,8,9]);
 assert.deepEqual(currentFullQualityJobs,['check','presentation','engineering-posix',
  ...Array.from({length:14},(_,i)=>`rules (${i+1}/14)`),...Array.from({length:9},(_,i)=>`engineering-posix (${i+1}/9)`),'impact','fast']);
 assert.equal(currentFullQualityJobs.length,28);assert.equal(new Set(currentFullQualityJobs).size,28);
 assert.equal(qualityShardJobs.length,23);
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 assert.match(workflow,/max-parallel: 6/,'the approved POSIX concurrency cap remains');
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

test('fourteen Windows and nine POSIX partitions cover every JS and raw Lua file once while the original budget remains binding',()=>{
 const js=discoverJs(),lua=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 for(const [platform,count]of [['win32',14],['linux',9]]){
  const bins=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files),union=bins.flat();
  assert.equal(new Set(union).size,union.length);assert.deepEqual(union.sort(),[...js].sort());
 }
 const short=file=>(timings.lua[file]??timings.unknownLuaMs)<10000;
 function combined(count){
  const jsLoads=jsShard(js,`1/${count}`,'win32').loads;
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(lua,`${i+1}/${count}`,timings,2));
  assert.equal(new Set(bins.flat()).size,lua.length);assert.deepEqual(bins.flat().sort(),[...lua].sort());
  const observed=file=>timings.luaShard[file]??timings.lua[file]??timings.unknownLuaMs;
  return bins.map((bin,i)=>{
   const pool=[0,0];
   for(const file of bin.filter(short).sort((a,b)=>(timings.lua[b]??timings.unknownLuaMs)-(timings.lua[a]??timings.unknownLuaMs)||a.localeCompare(b)))pool[pool[0]<=pool[1]?0:1]+=observed(file);
   return jsLoads[i]+bin.filter(file=>!short(file)).reduce((sum,file)=>sum+observed(file),0)+Math.max(...pool);
  });
 }
 assert.ok(Math.max(...combined(13))+60000>=1800000,'retain the actual thirteen-slot infeasibility witness');
 assert.ok(Math.max(...combined(14))+60000<1800000,'the unchanged thirty-minute budget and sixty-second sensitivity must pass');
 const posix=Array.from({length:9},(_,i)=>shardLuaScripts(lua,`${i+1}/9`,timings,2));
 assert.equal(new Set(posix.flat()).size,lua.length);assert.deepEqual(posix.flat().sort(),[...lua].sort());
});
