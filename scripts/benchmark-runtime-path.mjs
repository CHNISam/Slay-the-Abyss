// Opt-in only: no extra Full/fast workload. Build current data/UI first.
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {performance} from 'node:perf_hooks';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
const require=createRequire(import.meta.url);
export const phases=['begin','cold-host','warm-host','start-map','map-combat','combat-turn','idle-300','deck-roundtrip','terminal-reward','reward-map','disable'];
export const counters=['requireCalls','moduleLoads','nativeCalls','propertyWrites','snapshots'];
export function validateSample(sample){
 assert.deepEqual(sample.rows.map(row=>row.phase),phases,'missing/reordered runtime phase');
 for(const row of sample.rows){
  assert(Number.isFinite(row.elapsedMs)&&row.elapsedMs>=0);
  for(const key of counters)assert(Number.isSafeInteger(row[key])&&row[key]>=0,`invalid ${key}`);
  for(const key of ['rss','heapUsed'])assert(Number.isSafeInteger(row.memory[key])&&row.memory[key]>0);
 }
 assert(sample.rows[1].moduleLoads>0,'cold modules not observed');
 assert.equal(sample.rows[2].moduleLoads,0,'warm construction imported extra modules');
 assert(sample.rows.some(row=>row.nativeCalls>0)&&sample.rows.some(row=>row.propertyWrites>0),'native observer missing');
 assert(sample.rows.some(row=>row.snapshots>0),'snapshot observer missing');
 return sample;
}
export function percentile(values,p){
 assert(values.length>0&&values.every(Number.isFinite));assert(p>0&&p<=1);
 return [...values].sort((a,b)=>a-b)[Math.ceil(p*values.length)-1];
}
function sources(){
 const paths=[];
 const walk=dir=>{for(const entry of readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){const p=`${dir}/${entry.name}`;if(entry.isDirectory())walk(p);else if(entry.name.endsWith('.lua')||dir==='scripts/runtime-baseline')paths.push(p);}};
 for(const dir of ['src/lua','build/lua','tests/lua/support','scripts/runtime-baseline'])walk(dir);
 paths.push('scripts/benchmark-runtime-path.mjs','package-lock.json');
 const files=paths.sort().map(path=>({path,sha256:createHash('sha256').update(readFileSync(path)).digest('hex')}));
 return {sha256:createHash('sha256').update(JSON.stringify(files)).digest('hex'),files};
}
export function benchmark(){
 const identity=sources(),samples=[];
 for(let i=0;i<3;i++){
  const start=performance.now();
  const result=spawnSync(process.execPath,['scripts/runtime-baseline/worker.mjs'],{encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024});
  assert(!result.error&&result.status===0,result.error?.message||result.stderr);
  assert(result.stdout.includes('RUNTIME_BASELINE_PASS seed=1 idleFrames=300'));
  const lines=result.stdout.split('\n').filter(line=>line.startsWith('RUNTIME_BASELINE_JSON '));assert.equal(lines.length,1);
  samples.push({...validateSample(JSON.parse(lines[0].slice('RUNTIME_BASELINE_JSON '.length))),wallMs:performance.now()-start});
 }
 assert.deepEqual(sources(),identity,'sources changed while measuring');
 // Identical input must yield identical observed call counts, not just timings.
 const counts=s=>s.rows.map(row=>counters.map(key=>row[key]));
 for(const sample of samples)assert.deepEqual(counts(sample),counts(samples[0]),'nondeterministic call counts');
 const report={schemaVersion:1,createdAt:new Date().toISOString(),source:identity,node:process.version,fengari:require('fengari/package.json').version,platform:process.platform,arch:process.arch,seed:1,idleFrames:300,
  status:'OFFLINE_BASELINE_ONLY',limitations:['Nearest-rank n=3 P95 equals the maximum observed sample, not stable tail latency.','Three fresh VM samples, each with cold/warm Host construction; not before/after optimization pairs.','Warm phase includes first Host disable; no forced GC. RSS/heap are Node/Fengari, not device Lua memory.','Timing includes observer overhead. Native method calls use an explicit setter/listener/RefreshItems allowlist, excluding fixture helpers/callbacks and GetChild/GetChildren; direct property writes are separate and may also occur inside setters.','Terminal combat state is injected to measure reward transition, not combat victory.','No official client, GPU, FPS, device or release evidence; TASK-4.21 remains UNVERIFIED.'],samples,
  total:{p50WallMs:percentile(samples.map(s=>s.wallMs),.5),p95WallMs:percentile(samples.map(s=>s.wallMs),.95)},
  summary:phases.map(phase=>({phase,p50Ms:percentile(samples.map(s=>s.rows.find(r=>r.phase===phase).elapsedMs),.5),p95Ms:percentile(samples.map(s=>s.rows.find(r=>r.phase===phase).elapsedMs),.95)}))};
 mkdirSync('build/runtime-path-baseline',{recursive:true});writeFileSync('build/runtime-path-baseline/report.json',JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({source:identity.sha256,samples:samples.length,summary:report.summary}));return report;
}
if(import.meta.url===pathToFileURL(resolve(process.argv[1]||'')).href)benchmark();
