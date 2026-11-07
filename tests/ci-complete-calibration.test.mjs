import {beforeExecutionTimeoutWorkflow} from './helpers/auto-merge-workflow.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {ciCompleteCalibrationProof as proof,preCiCompleteCalibrationSource as project,preCurrentCiPlacementSource} from './helpers/ci-complete-calibration-source-inverse.mjs';
import {ciHostTimingProof,preCiHostTimingSource} from './helpers/ci-host-timing-source-inverse.mjs';
import {ciWindowsShapeProof,preCiWindowsShapeSource} from './helpers/ci-windows-shape-source-inverse.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {qualityShardMatrices as currentQualityShardMatrices,qualityShardJobs as currentQualityShardJobs} from '../scripts/ci-quality-shape.mjs';
import {currentFullQualityJobs} from '../scripts/verify-delivery.mjs';
import {discoverJs,partition,jsShard as currentJsShard,jsPlanningWeights as currentJsPlanningWeights,timings as currentTimings} from '../scripts/ci-shards.mjs';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex'),read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const path='scripts/ci-test-timings.json',binding=proof.files[path],before=JSON.parse(binding.beforeSource),after=JSON.parse(binding.afterSource),e=proof.evidence;
// The three original contracts own the frozen 16/12 calibration, including its
// unmeasured files. Current placement is checked separately below.
const timings=after;
const {qualityShardMatrices,qualityShardJobs}=await import('data:text/javascript,'+encodeURIComponent(proof.files['scripts/ci-quality-shape.mjs'].afterSource));
const historicalFullQualityJobs=['check','presentation','engineering-posix',...qualityShardJobs,'impact','fast'];
const jsPlanningWeights=(files,platform)=>Object.fromEntries(files.map(file=>[file,Math.max(timings.js[platform][file]??timings.unknownJsMs,timings.jsPlanning?.localLowerBounds?.[file]?.durationMs??0)]));
const jsShard=(files,value,platform)=>partition(files,value,jsPlanningWeights(files,platform),timings.unknownJsMs,Array.from({length:Number(value.split('/')[1])},(_,i)=>i===0?timings.initialMs[platform][0]:0));
const placementPath='docs/evidence/pr521-ci-placement-20261106.json',placementBytes=read(placementPath),placement=JSON.parse(placementBytes);
const floorPath='docs/evidence/pr521-run-max-planning-floor-20261106.json',floorBytes=read(floorPath),floorReceipt=JSON.parse(floorBytes),floorKey='tests/run-max-hp-config-inverse.test.mjs';
const localFloorPath='docs/evidence/power-shop-planning-20261107.json',localFloorBytes=read(localFloorPath),localFloorReceipt=JSON.parse(localFloorBytes),localFloorKey='tests/power-shop-boundaries.test.mjs';
// Added after the frozen #521 placement receipts. Never use these files to
// reconstruct historical shard assignments or invent historical measurements.
const postPlacementJs=['tests/intent-visibility-cache.test.mjs','tests/m7-core-final.test.mjs','tests/power-shop-boundaries.test.mjs','tests/pr-quality-evidence.test.mjs','tests/repository-costs.test.mjs','tests/runtime-path-baseline.test.mjs'];
const postPlacementLua=['tests/lua/intent_visibility_cache.lua'];
const currentLua=()=>readdirSync('tests/lua').filter(n=>n.endsWith('.lua')).map(n=>'tests/lua/'+n).sort();
const placementJs=()=>discoverJs().filter(file=>!postPlacementJs.includes(file));
const placementLua=()=>currentLua().filter(file=>!postPlacementLua.includes(file));
// These files were added after the frozen 725-file observations. They still
// belong to the current Full inventory and retain the unknown-file cost.
const postCalibrationJs=['tests/ci-complete-calibration.test.mjs','tests/native-ui-preview.test.mjs','tests/reference-ui-lab.test.mjs',
 'tests/actor-lifecycle.test.mjs','tests/actor-power-rules-boundary.test.mjs','tests/combat-lifecycle.test.mjs',
 'tests/core-lifecycle-complexity.test.mjs','tests/core-lifecycle-source-inverse.test.mjs',
 'tests/relic-query.test.mjs','tests/relic-query-architecture.test.mjs','tests/relic-query-source-inverse.test.mjs',
 'tests/purge-query.test.mjs','tests/purge-query-architecture.test.mjs',
 'tests/relic-lifecycle.test.mjs','tests/relic-lifecycle-boundary.test.mjs','tests/relic-lifecycle-mutations.test.mjs'].sort();
const postCalibrationLua=['tests/lua/actor_lifecycle.lua','tests/lua/actor_lifecycle_rules.lua','tests/lua/combat-lifecycle.lua',
 'tests/lua/relic_query_contract.lua','tests/lua/relic_query_rewards.lua','tests/lua/relic_query_cold_load.lua',
 'tests/lua/purge_query_contract.lua','tests/lua/purge_query_dynamic.lua','tests/lua/purge_query_cold_load.lua',
 'tests/lua/joust_event_slice_2.lua',
 ...['contracts','dynamic','fatal_guardian','fatal_native','fatal_orb','fatal_shared',
  'hooks_attacks','hooks_opening','hooks_turns','hp','rare','session','shop_early','shop_late','special',
  ...Array.from({length:9},(_,i)=>'parasite_'+String(i+1).padStart(2,'0')),
  ...Array.from({length:11},(_,i)=>'uncommon_'+String(i+1).padStart(2,'0'))]
  .map(group=>'tests/lua/relic_lifecycle_'+group+'.lua')].sort();

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
 const inventory=placementJs(),originalJs=inventory.filter(p=>!postCalibrationJs.includes(p)).sort();assert.equal(originalJs.length,725);
 assert.deepEqual(inventory.filter(p=>postCalibrationJs.includes(p)).sort(),postCalibrationJs);
 for(const platform of ['win32','linux'])for(const file of postCalibrationJs){
  assert.equal(after.js[platform][file],undefined,'new tests must not acquire fabricated historical measurements');
  assert.equal(jsPlanningWeights(postCalibrationJs,platform)[file],after.unknownJsMs);
 }
 const observedLua=placementLua();
 const originalLua=observedLua.filter(p=>!postCalibrationLua.includes(p));assert.equal(originalLua.length,1356);
 assert.equal(observedLua.length,1356+postCalibrationLua.length);
 assert.deepEqual(observedLua.filter(p=>postCalibrationLua.includes(p)),postCalibrationLua);
 for(const file of postCalibrationLua){
  assert.equal(after.luaShard[file],undefined,'new fixtures must not acquire fabricated historical placement costs');
  assert.equal(after.lua[file],undefined,'new fixtures must not acquire fabricated historical worker safety');
 }
 for(const runId of [e.sourceRun,e.groupRun]){
  for(const platform of ['win32','linux'])assert.deepEqual(e.observations.js.filter(r=>r.runId===runId&&r.platform===platform).map(r=>r.file).sort(),originalJs);
   assert.deepEqual(e.observations.lua.filter(r=>r.runId===runId).map(r=>r.file).sort(),originalLua);
 }
 for(const key of ['jsCalibrationUpdates','luaShardCalibrationUpdates']){
  assert.deepEqual(after[key].slice(0,-1),before[key]);expected[key].push(after[key].at(-1));
 }
 assert.equal(JSON.stringify(expected,null,2)+'\n',binding.afterSource,'every other source value/order stays untouched');
 assert.equal(preCurrentCiPlacementSource(path,read(path)),binding.afterSource);assert.deepEqual(timings,after);
 assert.deepEqual(after.lua,before.lua);assert.deepEqual(after.initialMs,before.initialMs);
 assert.deepEqual(after.jsPlanning,before.jsPlanning);assert.equal(after.unknownJsMs,before.unknownJsMs);assert.equal(after.unknownLuaMs,before.unknownLuaMs);
 const luaBlock=s=>s.slice(s.indexOf('  "lua": {'),s.indexOf('  "jsSource":'));
 assert.equal(luaBlock(binding.afterSource),luaBlock(binding.beforeSource),'literal original safety map bytes unchanged');
});

test('only complete approved sources reverse 16/12 to 14/9 to 13/9 and new timing to d580 to original 8e epoch',()=>{
 for(const [path,b]of Object.entries(proof.files)){
  assert.equal(preCurrentCiPlacementSource(path,read(path)),b.afterSource);
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

test('historical physical Windows16 POSIX12 Full33 covers final inventory under original budgets and unchanged setup reserve',()=>{
 assert.deepEqual(qualityShardMatrices.windows,Array.from({length:16},(_,i)=>i+1));assert.deepEqual(qualityShardMatrices.posix,Array.from({length:12},(_,i)=>i+1));
 const shape=proof.files['scripts/ci-quality-shape.mjs'];assert.equal(shape.afterSource,shape.beforeSource.replace('length:14','length:16').replace('length:9','length:12'));
 assert.equal(preCurrentCiPlacementSource('scripts/ci-quality-shape.mjs',read('scripts/ci-quality-shape.mjs')),shape.afterSource);assert.equal(qualityShardJobs.length,28);
 assert.deepEqual(historicalFullQualityJobs,['check','presentation','engineering-posix',...Array.from({length:16},(_,i)=>`rules (${i+1}/16)`),...Array.from({length:12},(_,i)=>`engineering-posix (${i+1}/12)`),'impact','fast']);
 assert.equal(historicalFullQualityJobs.length,33);assert.equal(new Set(historicalFullQualityJobs).size,33);
 const js=placementJs(),lua=placementLua();
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
 const workflow=beforeExecutionTimeoutWorkflow(read('.github/workflows/quality.yml'));assert.match(workflow,/max-parallel: 12/);assert.match(workflow,/timeout-minutes: 20/);assert.match(workflow,/local-special' && 75 \|\| 30/);
});

test('frozen Windows17 POSIX13 Full35 receipt covers its exact 741 JS and 1401 Lua files within unchanged budgets',()=>{
 assert.deepEqual(currentQualityShardMatrices.windows,Array.from({length:17},(_,i)=>i+1));
 assert.deepEqual(currentQualityShardMatrices.posix,Array.from({length:13},(_,i)=>i+1));
 assert.equal(read('scripts/ci-quality-shape.mjs'),proof.files['scripts/ci-quality-shape.mjs'].afterSource.replace('length:16','length:17').replace('length:12','length:13'));
 assert.equal(currentQualityShardJobs.length,30);
 assert.deepEqual(currentFullQualityJobs,['check','presentation','engineering-posix',...Array.from({length:17},(_,i)=>`rules (${i+1}/17)`),...Array.from({length:13},(_,i)=>`engineering-posix (${i+1}/13)`),'impact','fast']);
 assert.equal(currentFullQualityJobs.length,35);assert.equal(new Set(currentFullQualityJobs).size,35);
 const js=placementJs(),lua=placementLua();
 assert.equal(js.length,741);assert.equal(lua.length,1401);
 const totalJs=platform=>Object.values(currentJsPlanningWeights(js,platform)).reduce((sum,n)=>sum+n,0)+(currentTimings.initialMs[platform]?.[0]??0);
 const rawWork=lua.reduce((sum,file)=>sum+(currentTimings.luaShard[file]??currentTimings.lua[file]??currentTimings.unknownLuaMs)/((currentTimings.lua[file]??currentTimings.unknownLuaMs)<10000?2:1),0);
 assert.ok((totalJs('win32')+rawWork)/16+60000>1800000,'even ideal old Windows16 distribution exceeds its unchanged budget');
 assert.ok(totalJs('linux')/12+60000>1200000,'even ideal old POSIX12 distribution exceeds its unchanged budget');
 const maxima={},priorMaxima={};
 for(const [platform,count,budget]of [['win32',17,1800000],['linux',13,1200000]]){
  const loads=currentJsShard(js,`1/${count}`,platform).loads;
  const priorWeights=Object.fromEntries(js.map(file=>[file,Math.max(currentTimings.js[platform][file]??currentTimings.unknownJsMs,after.jsPlanning.localLowerBounds[file]?.durationMs??0)]));
  const priorLoads=partition(js,`1/${count}`,priorWeights,currentTimings.unknownJsMs,Array.from({length:count},(_,i)=>i===0?currentTimings.initialMs[platform][0]:0)).loads;
  const jsBins=Array.from({length:count},(_,i)=>currentJsShard(js,`${i+1}/${count}`,platform).files);
  assert.deepEqual(jsBins.flat().sort(),[...js].sort());assert.equal(new Set(jsBins.flat()).size,741);
  if(platform==='linux'){
   priorMaxima[platform]=Math.max(...priorLoads)+60000;
   maxima[platform]=Math.max(...loads)+60000;
   assert.ok(maxima[platform]<budget,`POSIX JS max+60s=${maxima[platform]} retains twenty-minute budget`);
   continue;
  }
  assert.deepEqual(loads,priorLoads,'the global floor does not raise the already observed Windows cost');
  const planning={...currentTimings,windowsJsShardMs:loads};
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(lua,`${i+1}/${count}`,planning,2));
  assert.deepEqual(bins.flat().sort(),[...lua].sort());assert.equal(new Set(bins.flat()).size,1401);
  const cost=f=>currentTimings.luaShard[f]??currentTimings.lua[f]??currentTimings.unknownLuaMs;
  const safety=f=>currentTimings.lua[f]??currentTimings.unknownLuaMs;
  const combined=bins.map((bin,i)=>{const pool=[0,0];for(const f of bin.filter(f=>safety(f)<10000).sort((a,b)=>safety(b)-safety(a)||a.localeCompare(b)))pool[pool[0]<=pool[1]?0:1]+=cost(f);
   return loads[i]+bin.filter(f=>safety(f)>=10000).reduce((sum,f)=>sum+cost(f),0)+Math.max(...pool);});
  maxima[platform]=Math.max(...combined)+60000;
  priorMaxima[platform]=maxima[platform];
  assert.ok(maxima[platform]<budget,`Windows combined max+60s=${maxima[platform]} retains thirty-minute budget`);
 }
 assert.deepEqual(priorMaxima,{win32:1707732,linux:1138396});
 assert.equal(placement.forecast.attempts[0].win32.maxPlusReserveMs,priorMaxima.win32);assert.equal(placement.forecast.attempts[0].linux.maxPlusReserveMs,priorMaxima.linux);
 assert.deepEqual(maxima,{win32:1707732,linux:1187278});
 const forecast=floorReceipt.planningEffect.forecast17_13;
 assert.deepEqual(forecast.before,{windowsMaxPlusReserveMs:priorMaxima.win32,posixMaxPlusReserveMs:priorMaxima.linux});
 assert.deepEqual(forecast.after,{windowsMaxPlusReserveMs:maxima.win32,posixMaxPlusReserveMs:maxima.linux});
 assert.equal(forecast.reserveMs,60000);assert.deepEqual(forecast.budgets,{windows:1800000,posix:1200000});assert.deepEqual(forecast.inventory,{js:741,lua:1401});
 assert.equal(forecast.workers,2);assert.equal(forecast.concurrencyCapUnchanged,12);assert.equal(forecast.actualFullPassClaim,false);
 const workflow=beforeExecutionTimeoutWorkflow(read('.github/workflows/quality.yml'));assert.match(workflow,/max-parallel: 12/);assert.match(workflow,/timeout-minutes: 20/);assert.match(workflow,/local-special' && 75 \|\| 30/);
});

test('current Full35 keeps exact coverage; forecast performance targets are advisory',t=>{
 const js=discoverJs(),lua=currentLua();
 assert.deepEqual(js.filter(file=>postPlacementJs.includes(file)).sort(),postPlacementJs);
 assert.deepEqual(lua.filter(file=>postPlacementLua.includes(file)),postPlacementLua);
 assert.equal(js.length,placement.inventory.js+postPlacementJs.length);
 assert.equal(lua.length,placement.inventory.lua+postPlacementLua.length);
 for(const platform of ['win32','linux'])for(const file of postPlacementJs){
  assert.equal(currentTimings.js[platform][file],undefined,'new files have no fabricated hosted measurements');
  if(file===localFloorKey){
   assert.equal(currentTimings.jsPlanning.localLowerBounds[file].durationMs,68586,'one complete local measurement supplies a planning floor, not hosted data');
   assert.equal(currentJsPlanningWeights([file],platform)[file],68586);
  }else{
   assert.equal(currentTimings.jsPlanning.localLowerBounds[file],undefined,'other new files have no fabricated planning floors');
   assert.equal(currentJsPlanningWeights([file],platform)[file],currentTimings.unknownJsMs);
  }
 }
 for(const file of postPlacementLua){
  assert.equal(currentTimings.lua[file],undefined,'new fixtures have no fabricated worker-safety measurements');
  assert.equal(currentTimings.luaShard[file],undefined,'new fixtures have no fabricated placement measurements');
 }
 for(const [platform,count,budget]of [['win32',17,1800000],['linux',13,1200000]]){
  const loads=currentJsShard(js,`1/${count}`,platform).loads;
  const jsBins=Array.from({length:count},(_,i)=>currentJsShard(js,`${i+1}/${count}`,platform).files);
  assert.deepEqual(jsBins.flat().sort(),[...js].sort());assert.equal(new Set(jsBins.flat()).size,js.length);
  if(platform==='linux'){
   t.diagnostic(`POSIX forecast with reserve ${Math.max(...loads)+60000} ms; target ${budget} ms (advisory)`);
   continue;
  }
  const planning={...currentTimings,windowsJsShardMs:loads};
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(lua,`${i+1}/${count}`,planning,2));
  assert.deepEqual(bins.flat().sort(),[...lua].sort());assert.equal(new Set(bins.flat()).size,lua.length);
  const cost=file=>currentTimings.luaShard[file]??currentTimings.lua[file]??currentTimings.unknownLuaMs;
  const safety=file=>currentTimings.lua[file]??currentTimings.unknownLuaMs;
  const combined=bins.map((bin,i)=>{const pool=[0,0];for(const file of bin.filter(file=>safety(file)<10000).sort((a,b)=>safety(b)-safety(a)||a.localeCompare(b)))pool[pool[0]<=pool[1]?0:1]+=cost(file);
   return loads[i]+bin.filter(file=>safety(file)>=10000).reduce((sum,file)=>sum+cost(file),0)+Math.max(...pool);});
  t.diagnostic(`Windows forecast with reserve ${Math.max(...combined)+60000} ms; target ${budget} ms (advisory)`);
 }
});

test('current placement authenticates 1458 complete successful assigned files without claiming failed containing jobs passed',()=>{
 assert.equal(hash(placementBytes),'5af2e277b3472262b57a12a6c13e387f4a008eeff0223b2a214bdddae115bd78');
 assert.equal(placement.schemaVersion,1);assert.equal(placement.kind,'pr521-native-file-placement');
 const run=placement.sourceRun;assert.equal(run.id,42176327678);assert.equal(run.attempt,1);
 assert.equal(run.headSha,'7be4b68ce2214d42273affe7a887bddf03bdbd87');assert.equal(run.treeSha,'c532b6efb5b752198be083be1c4dcf51b7c4167c');
 assert.equal(run.status,'completed');assert.equal(run.conclusion,'failure');
 assert.deepEqual(placement.inventory,{js:741,lua:1401,sourceShape:{windows:16,posix:12},plannedShape:{windows:17,posix:13}});
 assert.equal(placement.sourceRecords.length,28);assert.equal(placement.observations.length,1458);assert.equal(placement.rawLines.length,1458);
 assert.equal(placement.observationCount,1458);assert.deepEqual(placement.observedFileCounts,{win32:734,linux:724});
 const records=new Map(),assignments=new Map(),rawLines=new Map(),seen=new Set(),counts={win32:0,linux:0};
 const inventory=placementJs();
 for(const source of placement.sourceRecords){
  assert.ok(!records.has(source.jobId));records.set(source.jobId,source);
  assert.equal(source.runId,run.id);assert.equal(source.runAttempt,run.attempt);assert.equal(source.headSha,run.headSha);assert.equal(source.treeSha,run.treeSha);
  assert.equal(source.status,'completed');assert.equal(source.step.status,'completed');
  assert.match(source.sha256,/^[a-f0-9]{64}$/);assert.equal(source.path,`build/m7-full-7be-failure/job-${source.jobId}.log`);
  const match=source.jobName.match(/^(rules|engineering-posix) \((\d+)\/(16|12)\)$/);assert.ok(match);
  const platform=match[1]==='rules'?'win32':'linux',count=platform==='win32'?16:12;
  assert.equal(source.platform,platform);assert.equal(Number(match[3]),count);
  assignments.set(source.jobId,new Set(jsShard(inventory,`${match[2]}/${count}`,platform).files));
 }
 for(const row of placement.rawLines){const key=row.jobId+':'+row.line;assert.ok(!rawLines.has(key));rawLines.set(key,row.rawLine);}
 for(const row of placement.observations){
  const source=records.get(row.jobId);assert.ok(source);assert.equal(row.success,true);
  assert.ok(Number.isFinite(row.durationMs)&&row.durationMs>0);assert.ok(Number.isSafeInteger(row.line)&&row.line>0);
  assert.equal(row.platform,source.platform);assert.equal(row.jobName,source.jobName);assert.equal(row.jobConclusion,source.conclusion);assert.equal(row.jsStepConclusion,source.step.conclusion);
  assert.equal(row.logPath,source.path);assert.equal(row.logSha256,source.sha256);assert.ok(assignments.get(row.jobId).has(row.file));
  const raw=rawLines.get(row.jobId+':'+row.line);assert.equal(typeof raw,'string');
  const match=raw.match(/^(\S+) CI_FILE_TIMING (\{.*\})$/);assert.ok(match);assert.equal(match[1],row.timestamp);
  assert.deepEqual(JSON.parse(match[2]),{file:row.file,durationMs:row.durationMs,success:true});
  const time=Date.parse(row.timestamp);assert.ok(time>=Date.parse(source.step.startedAt)&&time<Date.parse(source.step.completedAt)+1000);
  const key=row.platform+':'+row.file;assert.ok(!seen.has(key));seen.add(key);counts[row.platform]++;
 }
 assert.deepEqual(counts,{win32:734,linux:724});
 assert.equal(placement.excluded.failedFileRows.length,13);assert.equal(placement.excluded.unfinishedOrUnobservedFiles.length,11);assert.deepEqual(placement.excluded.otherRejectedTimingRows,[]);
 const excluded=[...placement.excluded.failedFileRows,...placement.excluded.unfinishedOrUnobservedFiles];
 for(const row of excluded){const source=records.get(row.jobId);assert.ok(source);assert.ok(assignments.get(row.jobId).has(row.file));assert.ok(!seen.has(source.platform+':'+row.file));}
 for(const [jobId,assigned]of assignments){
  const rows=[...placement.observations,...excluded].filter(row=>row.jobId===jobId).map(row=>row.file);
  assert.deepEqual(rows.sort(),[...assigned].sort());assert.equal(new Set(rows).size,assigned.size);
 }
 const d5=placement.observations.find(row=>row.platform==='linux'&&row.file==='tests/relic-lifecycle.test.mjs');
 assert.equal(d5.durationMs,461486.846292);assert.equal(d5.success,true);assert.equal(d5.jsStepConclusion,'cancelled');
});

test('current 129 placement raises reconstruct exact timings while preserving all old floors and raw worker safety bytes',()=>{
 const expected=structuredClone(after),changes=[],raisedCounts={win32:0,linux:0};
 for(const row of placement.observations){
  const map=expected.js[row.platform],hadOwnBefore=Object.hasOwn(map,row.file),oldMs=map[row.file]??after.unknownJsMs,newMs=Math.max(oldMs,Math.ceil(row.durationMs));
  if(newMs>oldMs){map[row.file]=newMs;changes.push({...row,oldMs,newMs,raiseMs:newMs-oldMs,hadOwnBefore});raisedCounts[row.platform]++;}
 }
 assert.equal(changes.length,129);assert.deepEqual(raisedCounts,{win32:70,linux:59});assert.deepEqual(changes,placement.changes);
 assert.equal(placement.raisedCount,129);assert.deepEqual(placement.raisedCounts,raisedCounts);
 assert.equal(placement.previousMapSha256,hash(JSON.stringify(after.js)));assert.equal(placement.resultingMapSha256,hash(JSON.stringify(expected.js)));
 const update=currentTimings.jsCalibrationUpdates.at(-1);
 assert.deepEqual(currentTimings.jsCalibrationUpdates.slice(0,-1),after.jsCalibrationUpdates);
 assert.equal(update.runId,placement.sourceRun.id);assert.equal(update.runAttempt,1);assert.equal(update.headSha,placement.sourceRun.headSha);assert.equal(update.treeSha,placement.sourceRun.treeSha);assert.equal(update.conclusion,'failure');
 assert.deepEqual(update.sourceRecords,placement.sourceRecords);assert.deepEqual(update.observedFileCounts,placement.observedFileCounts);assert.equal(update.observationCount,1458);assert.deepEqual(update.raisedCounts,raisedCounts);
 assert.deepEqual(update.excludedFailedCounts,{win32:7,linux:6});assert.deepEqual(update.excludedUnfinishedCounts,{win32:0,linux:11});
 assert.equal(update.detailedReceipt,placementPath);assert.equal(update.detailedReceiptSha256,hash(placementBytes));
 expected.jsCalibrationUpdates.push(update);
 const priorBytes=JSON.stringify(expected,null,2)+'\n';
 assert.equal(hash(priorBytes),'3f12a6a2cffe9516fae02de768d545a2847e5632efedb72b0298a8bb26ca9ee5','the original 129 raises and one provenance append recover their exact complete timing epoch');
 assert.equal(hash(floorBytes),'503e94c83632f032d6b160ae24ec6b3d33f8d91c4c0f734d91056f4371a750b0');
 assert.equal(floorReceipt.schemaVersion,1);assert.equal(floorReceipt.kind,'cross-platform-planning-floor');assert.equal(floorReceipt.file,floorKey);assert.equal(floorReceipt.beforeTimingsLfSha256,hash(priorBytes));
 assert.equal(Object.hasOwn(floorReceipt,'afterTimingsLfSha256'),false,'receipt has no circular after-source identity');
 assert.equal(floorReceipt.originalPlacementEvidence.path,placementPath);assert.equal(floorReceipt.originalPlacementEvidence.sha256,hash(placementBytes));assert.deepEqual(floorReceipt.originalPlacementEvidence.sourceRun,placement.sourceRun);
 const windows=floorReceipt.completedWindowsSource,row=windows.observation,source=windows.sourceRecord;
 assert.deepEqual(row,placement.observations.find(observation=>observation.platform==='win32'&&observation.file===floorKey));
 assert.deepEqual(source,placement.sourceRecords.find(record=>record.jobId===row.jobId));
 assert.equal(windows.rawLine,placement.rawLines.find(line=>line.jobId===row.jobId&&line.line===row.line).rawLine);
 assert.equal(row.durationMs,889637.0668);assert.equal(row.success,true);assert.equal(row.platform,'win32');assert.equal(source.step.status,'completed');assert.equal(source.step.conclusion,'success');assert.equal(source.conclusion,'cancelled');
 assert.equal(windows.ceilMs,Math.ceil(row.durationMs));assert.equal(windows.ceilMs,889638);assert.equal(floorReceipt.durationMs,windows.ceilMs);assert.equal(floorReceipt.environment,'hosted Windows');
 const censored=floorReceipt.censoredLinuxSource;
 assert.equal(censored.plannedCount,58);assert.equal(censored.completedCount,44);assert.equal(censored.firstUncompletedFile,floorKey);
 assert.deepEqual(censored.completeSuccessfulPrefix.map(row=>row.file),censored.plannedFiles.slice(0,44));assert.equal(censored.plannedFiles[44],floorKey);
 assert.equal(censored.censoredWindowMs,629181);assert.equal(censored.measurementImported,false);assert.equal(censored.censoringIsNotRuntimeOrPass,true);
 assert.equal(currentTimings.js.linux[floorKey],254137,'the unfinished Linux duration never replaces its previous complete observation');
 assert.equal(floorReceipt.planningEffect.previousEffectiveLinuxMs,254137);assert.equal(floorReceipt.planningEffect.previousEffectiveWindowsMs,889638);assert.equal(floorReceipt.planningEffect.newFloorMs,889638);
 assert.deepEqual(floorReceipt.planningEffect.additionalTotalWorkMs,{linux:635501,win32:0});
 expected.jsPlanning.model=after.jsPlanning.model.replace('explicit local lower bounds.','explicit local and cross-platform planning floors.');
 assert.notEqual(expected.jsPlanning.model,after.jsPlanning.model);
 expected.jsPlanning.localLowerBounds[floorKey]={durationMs:889638,environment:'hosted Windows',coverage:floorReceipt.coverage,
  kind:'Planning-only cross-platform floor from a complete successful hosted Windows same-file observation; not a Linux measurement or censored elapsed-time sample.',
  sourceLog:row.logPath,sourceLogSha256:row.logSha256,sourceRunId:source.runId,sourceHeadSha:source.headSha,sourceJobId:row.jobId,sourceReceipt:floorPath,sourceReceiptSha256:hash(floorBytes)};
 assert.equal(hash(JSON.stringify(expected,null,2)+'\n'),'a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24','all 129 raises and the nine prior floors retain their exact complete epoch');
 assert.equal(hash(localFloorBytes),'52570c893c538ac0c5ab592e3b6d89afe883495ea6624fa4f35abaad3053f8f7','complete local planning provenance remains immutable');
 assert.equal(localFloorReceipt.schemaVersion,1);assert.equal(localFloorReceipt.kind,'local-complete-file-planning-floor');assert.equal(localFloorReceipt.file,localFloorKey);
 assert.equal(localFloorReceipt.beforeTimingsLfSha256,hash(JSON.stringify(expected,null,2)+'\n'));assert.equal(localFloorReceipt.durationMs,68586);
 const localRun=localFloorReceipt.completedRun;assert.equal(hash(localRun.rawTap),localRun.sha256);
 for(const pattern of [/ℹ tests 8\r?\n/,/ℹ pass 8\r?\n/,/ℹ fail 0\r?\n/,/ℹ skipped 0\r?\n/])assert.match(localRun.rawTap,pattern);
 assert.equal(Number(localRun.rawTap.match(/ℹ duration_ms ([\d.]+)/)[1]),68585.5837);assert.equal(localRun.durationMs,68585.5837);assert.equal(Math.ceil(localRun.durationMs),localFloorReceipt.durationMs);
 assert.deepEqual([localRun.tests,localRun.passed,localRun.failed,localRun.skipped,localRun.checkpoints,localRun.bytesPerSide],[8,8,0,0,694,55585110]);
 assert.equal(localFloorReceipt.environment.node,'v24.18.0');assert.equal(localFloorReceipt.environment.platform,'win32');assert.match(localFloorReceipt.environment.scope,/not a hosted Windows or Linux measurement/);
 assert.equal(localRun.testProcessMaxRSSKiB,2324108);assert.match(localRun.rawTap,/POWER_SHOP_RESOURCE \{"testProcessMaxRSSKiB":2324108\}/);
 assert.equal(localRun.reports.reduce((n,r)=>n+r.checkpoints,0),694);assert.equal(localRun.reports.reduce((n,r)=>n+r.bytesPerSide,0),55585110);
 assert.equal(localFloorReceipt.sourceIdentity.ownerFiles.length,5);assert.ok(localFloorReceipt.sourceIdentity.selectedFiles.some(f=>f.path===localFloorKey));
 const oldLocal=localFloorReceipt.historicalFullEncoding;assert.equal(oldLocal.durationMs,153107.4336);assert.equal(hash(oldLocal.rawTap),oldLocal.sha256);assert.equal(oldLocal.checkpoints,694);assert.equal(oldLocal.bytesPerSide,335541022);
 assert.equal(oldLocal.rejectedPlanningForecast.linuxMaxPlusReserveMs,1201367);assert.match(oldLocal.reason,/not a controlled speed comparison/);
 expected.jsPlanning.localLowerBounds[localFloorKey]={durationMs:68586,environment:'local Windows',coverage:'8/8 complete file passed; 0 skipped; stable complete-graph observer',
  kind:'Local complete-run planning estimate only; not hosted or Linux measurement.',sourceLog:localRun.path,sourceLogSha256:localRun.sha256,sourceReceipt:localFloorPath,sourceReceiptSha256:hash(localFloorBytes)};
 assert.equal(JSON.stringify(expected,null,2)+'\n',read(path),'after the original 129 raises and nine floors, only the sourced local planning estimate may change complete timing bytes');
 assert.deepEqual(currentTimings,expected);
 for(const platform of ['win32','linux'])for(const [file,value]of Object.entries(after.js[platform]))assert.ok(currentTimings.js[platform][file]>=value);
 const luaBlock=s=>s.slice(s.indexOf('  "lua": {'),s.indexOf('  "jsSource":'));
 assert.equal(luaBlock(read(path)),luaBlock(binding.afterSource),'literal worker-safety bytes remain frozen');
 for(const key of ['lua','luaShard','luaShardCalibrationUpdates','initialMs','unknownJsMs','unknownLuaMs'])assert.deepEqual(currentTimings[key],after[key],key+' remains unchanged');
 const priorFloors=structuredClone(currentTimings.jsPlanning.localLowerBounds);delete priorFloors[floorKey];delete priorFloors[localFloorKey];assert.deepEqual(priorFloors,after.jsPlanning.localLowerBounds,'all eight existing local floors remain exact');assert.equal(Object.keys(priorFloors).length,8);
 for(const platform of ['win32','linux'])assert.equal(currentJsPlanningWeights([floorKey],platform)[floorKey],889638);
 assert.equal(placement.forecast.reserveMs,60000);assert.deepEqual(placement.forecast.budgets,{win32:1800000,linux:1200000});assert.equal(placement.forecast.workers,2);assert.equal(placement.forecast.concurrencyCapUnchanged,12);
});

test('only two exact current source identities enter the unchanged pure historical CI chain and all byte drift remains visible',()=>{
 const identities={
  'scripts/ci-test-timings.json':'1832a5f395318af201322666f31f601ffb183c0870fcc6fa62a5d8e48af0922d',
  'scripts/ci-quality-shape.mjs':'0d6c82c2a7e7db82e276eb563978d5253d9a225039329e171ed3f907f98609d1',
 };
 for(const [path,digest]of Object.entries(identities)){
  const source=read(path),b=proof.files[path];assert.equal(hash(source),digest);
  for(const input of [source,source.replaceAll('\n','\r\n')]){
   assert.equal(preCurrentCiPlacementSource(path,input),b.afterSource);assert.equal(project(path,input),b.beforeSource);
   const legacy=path.endsWith('.json')?preCiHostTimingSource(path,b.beforeSource):preCiWindowsShapeSource(path,b.beforeSource);
   assert.equal(preIntegrationSource(path,input,'base',{readSource(){assert.fail('pure CI source projection must not read any live owner');}}),legacy);
  }
  for(const value of [b.afterSource,b.beforeSource,undefined,null,{},123])assert.equal(preCurrentCiPlacementSource(path,value),value);
  assert.equal(preCurrentCiPlacementSource('foreign',source),source);
  const other=Object.keys(identities).find(other=>other!==path);assert.equal(preCurrentCiPlacementSource(other,source),source);
  const mutants=[source+'\n',source.slice(1),source.replaceAll('\n','\n '),source.replace('length:17','length:16'),source.replace('length:13','length:12'),
   source.replace('"unknownJsMs": 10000','"unknownJsMs": 9999'),source.replace('"unknownJsMs": 10000','"unknownJsMs": 10000,\n  "unknownJsMs": 10000'),
   source.replace('"conclusion": "failure"','"conclusion": "success"'),source.replace('"durationMs": 889638','"durationMs": 629181'),
   source.replace('"tests/run-max-hp-config-inverse.test.mjs": 254137','"tests/run-max-hp-config-inverse.test.mjs": 889638'),
   source.replace('not a Linux measurement or censored elapsed-time sample.','a Linux measurement and censored elapsed-time sample.')].filter(value=>value!==source);
  for(const mutant of mutants){assert.equal(preCurrentCiPlacementSource(path,mutant),mutant);assert.equal(project(path,mutant),mutant);assert.notEqual(hash(mutant),b.beforeSha256);}
 }
});
