// Opt-in A/B timing. Full-state equivalence remains a separate regression.
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import {performance} from 'node:perf_hooks';
const require=createRequire(import.meta.url);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
function identity(){
 const paths=[];
 for(const dir of ['src/lua','build/lua','tests/lua/support','scripts/runtime-baseline']){
  for(const entry of readdirSync(dir,{withFileTypes:true}))if(entry.isFile()&&entry.name.endsWith('.lua'))paths.push(`${dir}/${entry.name}`);
 }
 paths.push('tests/fixtures/intent-visibility/before.lua','tests/helpers/intent-visibility-vm.mjs','tests/helpers/lua-graph-observer.mjs','scripts/benchmark-intent-visibility.mjs','package-lock.json');
 const files=paths.sort().map(path=>({path,sha256:hash(readFileSync(path))}));
 return {sha256:hash(JSON.stringify(files)),files};
}
const source=identity(),samples=[];
for(let pair=1;pair<=3;pair++)for(const side of pair%2?['before','after']:['after','before']){
 const startedAt=new Date().toISOString(),start=performance.now();
 const result=spawnSync(process.execPath,['tests/helpers/intent-visibility-vm.mjs',side,'--timed'],{encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024});
 const wallMs=performance.now()-start;
 assert.ifError(result.error);assert.equal(result.status,0,result.stderr+'\n'+result.stdout.slice(-2000));
 assert.match(result.stdout,/RUNTIME_BASELINE_PASS seed=1 idleFrames=300/);
 assert(!result.stdout.includes('VISIBILITY_GRAPH '),'timed path serialized a graph');
 const lines=result.stdout.split('\n').filter(line=>line.startsWith('VISIBILITY_COUNTS '));assert.equal(lines.length,1);
 const counts=JSON.parse(lines[0].slice('VISIBILITY_COUNTS '.length));
 const workload=result.stdout.split('\n').filter(line=>!line.startsWith('VISIBILITY_COUNTS ')).join('\n');
 samples.push({pair,side,startedAt,wallMs,counts,workloadSha256:hash(workload)});
}
assert.deepEqual(identity(),source,'inputs changed while sampling');
for(const sample of samples){
 assert.equal(sample.workloadSha256,samples[0].workloadSha256,'workload output changed');
 const sameSide=samples.find(s=>s.side===sample.side);assert.deepEqual(sample.counts,sameSide.counts,'same-side operation counts changed');
}
for(let pair=1;pair<=3;pair++){
 const before=samples.find(s=>s.pair===pair&&s.side==='before'),after=samples.find(s=>s.pair===pair&&s.side==='after');
 assert.deepEqual(before.counts.map(row=>row.phase),after.counts.map(row=>row.phase));
 for(let i=0;i<before.counts.length;i++)for(const index of [0,1,4])assert.equal(before.counts[i].counts[index],after.counts[i].counts[index],'require/load/snapshot workload changed');
 assert.deepEqual(before.counts.find(r=>r.phase==='idle-300').counts,[900,0,3600,7200,0]);
 assert.deepEqual(after.counts.find(r=>r.phase==='idle-300').counts,[900,0,1800,5400,0]);
}
const quantile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.ceil(p*values.length)-1];
const summary=Object.fromEntries(['before','after'].map(side=>{const values=samples.filter(s=>s.side===side).map(s=>s.wallMs);return [side,{p50Ms:quantile(values,.5),p95Ms:quantile(values,.95)}];}));
const report={schemaVersion:1,source,node:process.version,fengari:require('fengari/package.json').version,platform:process.platform,arch:process.arch,samples,summary,
 limitations:['Three interleaved pairs, each fresh VM; n=3 nearest-rank P95 is the maximum, not stable tail latency.','Same instrumentation on both sides, without final graph serialization; wall time includes startup and observer cost.','Same business stdout and require/load/snapshot counts; complete final graph equivalence is separately tested.','This fixture has one enemy and explicit terminal combat setup; not general gameplay/device/FPS evidence.','Source identity binds this isolated core combination, not a later integration.']};
mkdirSync('build/intent-visibility',{recursive:true});writeFileSync('build/intent-visibility/timing.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({source:source.sha256,summary,pairs:samples.map(s=>({pair:s.pair,side:s.side,wallMs:s.wallMs}))}));
