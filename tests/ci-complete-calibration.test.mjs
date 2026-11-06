import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {ciCompleteCalibrationProof as proof,preCiCompleteCalibrationSource as project} from './helpers/ci-complete-calibration-source-inverse.mjs';
import {ciHostTimingProof,preCiHostTimingSource} from './helpers/ci-host-timing-source-inverse.mjs';
import {ciWindowsShapeProof,preCiWindowsShapeSource} from './helpers/ci-windows-shape-source-inverse.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {qualityShardMatrices,qualityShardJobs} from '../scripts/ci-quality-shape.mjs';
import {currentFullQualityJobs} from '../scripts/verify-delivery.mjs';
import {discoverJs,jsShard,jsPlanningWeights,timings} from '../scripts/ci-shards.mjs';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex'),read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const path='scripts/ci-test-timings.json',binding=proof.files[path],before=JSON.parse(binding.beforeSource),after=JSON.parse(binding.afterSource),e=proof.evidence;
// These files were added after the frozen 725-file observations. They still
// belong to the current Full inventory and retain the unknown-file cost.
const postCalibrationJs=['tests/ci-complete-calibration.test.mjs','tests/native-ui-preview.test.mjs','tests/reference-ui-lab.test.mjs'];
const postCalibrationLua=['tests/lua/joust_event_slice_2.lua'];

test('complete native successful rows authenticate every observed file and only raise effective placement costs',()=>{
 assert.equal(e.lockedObservationsSha256,'a80b5fe95fcfb0b4d5fedf839045100466423f3129c000ce2eef642cc31c421d');
 assert.equal(e.sourceHead,'41a99579e41ea685a1d71d9ce6e6e603839968db');assert.equal(e.groupHead,'8ba123b90ef176ad240c25154059597ec2c34b9b');
 assert.equal(e.sharedTree,'65f5bb53e19fd6055488b928865804e132285fc2');assert.equal(e.sourceRecords.length,46);
 const expected=structuredClone(before),observedJs=new Set(),raw=new Set();
 function authenticate(row,kind){
  const source=e.sourceRecords.find(s=>s.id===row.jobId&&s.runId===row.runId);assert.ok(source);
  assert.equal(row.logSha256,source.sha256);assert.match(row.logSha256,/^[a-f0-9]{64}$/);assert.ok(Number.isSafeInteger(row.line)&&row.line>0);
  assert.ok(Number.isFinite(row.durationMs)&&row.durationMs>0);
  const step=kind==='js'?source.jsStep:source.rawStep;assert.equal(step.status,'completed');assert.equal(step.conclusion,'success');
  const time=Date.parse(row.rawLine.split(' ')[0]);assert.ok(time>=Date.parse(step.started_at)&&time<Date.parse(step.completed_at)+1000,'outer completed-success step is authoritative');
  if(kind==='js'){
   assert.equal(row.platform,source.platform);assert.equal(row.success,true);
   const match=row.rawLine.match(/CI_FILE_TIMING (\{.*\})/);assert.ok(match);
   assert.deepEqual(JSON.parse(match[1]),{file:row.file,durationMs:row.durationMs,success:true});
  }else{
   assert.equal(source.platform,'win32');const match=row.rawLine.match(/Lua fixture ([^:]+): (\d+) ms/);assert.ok(match);
   assert.equal(match[1],row.file);assert.equal(Number(match[2]),row.durationMs);
  }
 }
 for(const row of e.observations.js){authenticate(row,'js');const key=[row.runId,row.platform,row.file].join(':');assert.ok(!observedJs.has(key));observedJs.add(key);
  expected.js[row.platform][row.file]=Math.max(expected.js[row.platform][row.file]??before.unknownJsMs,Math.ceil(row.durationMs));}
 for(const row of e.observations.lua){authenticate(row,'lua');const key=[row.runId,row.file].join(':');assert.ok(!raw.has(key));raw.add(key);
  expected.luaShard[row.file]=Math.max(expected.luaShard[row.file]??before.lua[row.file]??before.unknownLuaMs,Math.ceil(row.durationMs));}
 assert.equal(observedJs.size,2900);assert.equal(raw.size,2712);assert.equal(e.excludedEmbeddedLua,14);
 const inventory=discoverJs(),originalJs=inventory.filter(p=>!postCalibrationJs.includes(p)).sort();assert.equal(originalJs.length,725);
 assert.deepEqual(inventory.filter(p=>postCalibrationJs.includes(p)).sort(),postCalibrationJs);
 for(const platform of ['win32','linux'])for(const file of postCalibrationJs){
  assert.equal(after.js[platform][file],undefined,'new tests must not acquire fabricated historical measurements');
  assert.equal(jsPlanningWeights(postCalibrationJs,platform)[file],after.unknownJsMs);
 }
  const lua=readdirSync('tests/lua').filter(n=>n.endsWith('.lua')).map(n=>'tests/lua/'+n).sort();
  const originalLua=lua.filter(file=>!postCalibrationLua.includes(file));assert.equal(originalLua.length,1356);
  assert.deepEqual(lua.filter(file=>postCalibrationLua.includes(file)),postCalibrationLua);
  for(const file of postCalibrationLua){assert.equal(after.lua[file],undefined);assert.equal(after.luaShard[file],undefined,'new raw entries must not acquire fabricated historical measurements');}
 for(const runId of [e.sourceRun,e.groupRun]){
  for(const platform of ['win32','linux'])assert.deepEqual(e.observations.js.filter(r=>r.runId===runId&&r.platform===platform).map(r=>r.file).sort(),originalJs);
   assert.deepEqual(e.observations.lua.filter(r=>r.runId===runId).map(r=>r.file).sort(),originalLua);
 }
 for(const key of ['jsCalibrationUpdates','luaShardCalibrationUpdates']){
  assert.deepEqual(after[key].slice(0,-1),before[key]);expected[key].push(after[key].at(-1));
 }
 assert.equal(JSON.stringify(expected,null,2)+'\n',binding.afterSource,'every other source value/order stays untouched');
 assert.equal(read(path),binding.afterSource);assert.deepEqual(timings,after);
 assert.deepEqual(after.lua,before.lua);assert.deepEqual(after.initialMs,before.initialMs);
 assert.deepEqual(after.jsPlanning,before.jsPlanning);assert.equal(after.unknownJsMs,before.unknownJsMs);assert.equal(after.unknownLuaMs,before.unknownLuaMs);
 const luaBlock=s=>s.slice(s.indexOf('  "lua": {'),s.indexOf('  "jsSource":'));
 assert.equal(luaBlock(binding.afterSource),luaBlock(binding.beforeSource),'literal original safety map bytes unchanged');
});

test('only complete approved sources reverse 16/12 to 14/9 to 13/9 and new timing to d580 to original 8e epoch',()=>{
 for(const [path,b]of Object.entries(proof.files)){
  assert.equal(read(path),b.afterSource);
  for(const source of [b.afterSource,b.afterSource.replaceAll('\n','\r\n')])assert.equal(project(path,source),b.beforeSource);
  const legacy=path.endsWith('.json')?preCiHostTimingSource(path,b.beforeSource):preCiWindowsShapeSource(path,b.beforeSource);
  assert.equal(legacy,path.endsWith('.json')?ciHostTimingProof.beforeSource:ciWindowsShapeProof.beforeSource);
  assert.equal(preIntegrationSource(path,b.afterSource,'base',{readSource(){assert.fail('CI projection must not read live owners');}}),legacy);
  for(const value of [b.beforeSource,null,{},undefined,17])assert.equal(project(path,value),value);
  for(const value of [b.afterSource+'\n',b.afterSource.slice(1),b.afterSource.replace('length:16','length:15'),b.afterSource.replace('length:12','length:9')].filter(v=>v!==b.afterSource)){
   assert.equal(project(path,value),value);assert.notEqual(hash(value),b.beforeSha256);
  }
  assert.equal(project('foreign',b.afterSource),b.afterSource);
 }
 const key='tests/game-ui-host-result.test.mjs',value=after.js.win32[key],entry=JSON.stringify(key)+': '+value;
 const at=binding.afterSource.indexOf('"kind": "complete-multi-run"');assert.ok(at>0);
 const prefix=binding.afterSource.slice(0,at),multi=binding.afterSource.slice(at);
 const sourceMetadataMutations=[multi.replace('"complete-multi-run"','"single-run"'),multi.replace('"runAttempt": 1','"runAttempt": 2'),multi.replace('"treeSha": "'+e.sharedTree+'"','"treeSha": "'+'f'.repeat(40)+'"'),multi.replace('"conclusion": "success"','"conclusion": "failure"')].map(s=>prefix+s);
 for(const altered of [binding.afterSource.replace(entry,JSON.stringify(key)+': '+(value+1)),binding.afterSource.replace(entry,entry+',\n      '+entry),binding.afterSource.replace(entry,JSON.stringify(key)+': '+value+'.0'),binding.afterSource.replace('"unknownJsMs": 10000','"unknownJsMs": 9999'),...sourceMetadataMutations]){
  assert.notEqual(altered,binding.afterSource);assert.equal(project(path,altered),altered);assert.notEqual(hash(altered),binding.beforeSha256);
 }
 assert.ok(Object.isFrozen(proof.files));assert.ok(Object.isFrozen(e.observations.lua[0]));
});

test('physical Windows16 POSIX12 Full33 covers final inventory under original budgets and unchanged setup reserve',()=>{
 assert.deepEqual(qualityShardMatrices.windows,Array.from({length:16},(_,i)=>i+1));assert.deepEqual(qualityShardMatrices.posix,Array.from({length:12},(_,i)=>i+1));
 const shape=proof.files['scripts/ci-quality-shape.mjs'];assert.equal(shape.afterSource,shape.beforeSource.replace('length:14','length:16').replace('length:9','length:12'));
 assert.equal(read('scripts/ci-quality-shape.mjs'),shape.afterSource);assert.equal(qualityShardJobs.length,28);
 assert.deepEqual(currentFullQualityJobs,['check','presentation','engineering-posix',...Array.from({length:16},(_,i)=>`rules (${i+1}/16)`),...Array.from({length:12},(_,i)=>`engineering-posix (${i+1}/12)`),'impact','fast']);
 assert.equal(currentFullQualityJobs.length,33);assert.equal(new Set(currentFullQualityJobs).size,33);
 const js=discoverJs(),lua=readdirSync('tests/lua').filter(n=>n.endsWith('.lua')).map(n=>'tests/lua/'+n);
 assert.equal(js.length,725+postCalibrationJs.length,'725 observed files plus every explicitly unmeasured new test');
 for(const [platform,count,budget]of [['win32',16,1800000],['linux',12,1200000]]){
  const loads=jsShard(js,`1/${count}`,platform).loads;
  const jsBins=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files);
  assert.deepEqual(jsBins.flat().sort(),[...js].sort());assert.equal(new Set(jsBins.flat()).size,js.length);
  if(platform==='linux'){
   assert.ok(Math.max(...loads)+60000<budget,`POSIX JS-only max+60s=${Math.max(...loads)+60000} retains original twenty-minute budget`);
   continue;
  }
  const planning={...timings,windowsJsShardMs:loads};
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(lua,`${i+1}/${count}`,planning,2));
  assert.deepEqual(bins.flat().sort(),[...lua].sort());assert.equal(new Set(bins.flat()).size,lua.length);
  const cost=f=>timings.luaShard[f]??timings.lua[f]??timings.unknownLuaMs,safety=f=>timings.lua[f]??timings.unknownLuaMs;
  const combined=bins.map((bin,i)=>{const pool=[0,0];for(const f of bin.filter(f=>safety(f)<10000).sort((a,b)=>safety(b)-safety(a)||a.localeCompare(b)))pool[pool[0]<=pool[1]?0:1]+=cost(f);
   return loads[i]+bin.filter(f=>safety(f)>=10000).reduce((s,f)=>s+cost(f),0)+Math.max(...pool);});
  assert.ok(Math.max(...combined)+60000<budget,`${platform} exact inventory max+60s=${Math.max(...combined)+60000} must retain original budget ${budget}`);
 }
 const workflow=read('.github/workflows/quality.yml');assert.match(workflow,/max-parallel: 12/);assert.match(workflow,/timeout-minutes: 20/);assert.match(workflow,/local-special' && 75 \|\| 30/);
});
