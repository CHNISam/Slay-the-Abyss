// Opt-in, fixed protocol. Do not rerun to select favorable outcomes.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync,mkdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {loadavg,cpus,platform,release,tmpdir} from 'node:os';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const protocol={warmupPairs:4,measuredPairs:20,order:'odd AB, even BA, including warmups',freshVm:true,timeoutMs:30000,bootstrapIterations:50000,bootstrapSeed:20261106,confidence:'one-sided 95% percentile bootstrap of mean paired log wall ratio',acceptance:'upper95 <= 1.00 and after P50/P95 <= before; all workload/source checks pass',outliers:'all retained; no retry or replacement; any child failure invalidates the run',scope:'complete original Host route including cold/warm construction; warmups prime OS caches, not fresh-process JIT'};
const helper='tests/helpers/intent-visibility-vm.mjs',original=readFileSync(helper,'utf8');
function replaceOnce(source,old,next){assert.equal(source.split(old).length,2);return source.replace(old,next);}
let executable=replaceOnce(original,"from './lua-graph-observer.mjs'",'from '+JSON.stringify(pathToFileURL(resolve('tests/helpers/lua-graph-observer.mjs')).href));
executable=replaceOnce(executable,'createRequire(import.meta.url)','createRequire('+JSON.stringify(resolve(helper))+')');
executable+="\nconsole.log('VISIBILITY_CPU '+JSON.stringify(process.cpuUsage()));\n";
// Bind exactly the same original A/B input inventory plus this protocol program.
const manifest=JSON.parse(readFileSync('docs/evidence/intent-visibility-integrated-timing-20261106.json')).source.files.map(file=>file.path);
manifest.push('scripts/benchmark-intent-visibility-controlled.mjs');manifest.sort();assert.equal(new Set(manifest).size,manifest.length);
const identity=()=>{const files=manifest.map(path=>({path,sha256:hash(readFileSync(path))}));return {sha256:hash(JSON.stringify(files)),files};};
const source=identity(),samples=[],startedAt=new Date().toISOString();
const report={schemaVersion:1,protocol,protocolSha256:hash(JSON.stringify(protocol)),source,executable,executableSha256:hash(executable),startedAt,environment:{node:process.version,platform:platform(),release:release(),arch:process.arch,cpu:cpus()[0]?.model,logicalCpus:cpus().length},samples,limitations:['Shared cloud host load is recorded, not controlled; bootstrap uncertainty does not remove systematic drift.','Fresh processes include Node/Fengari JIT and observer overhead. No device/FPS claim.','Twenty pairs are finite, not stable tail latency; P95 is nearest-rank.','Previous unfavorable three-pair evidence remains authoritative history; this predeclared experiment is separate.']};
const output='build/intent-visibility/controlled.json';mkdirSync('build/intent-visibility',{recursive:true});
let created=false;
const save=()=>{writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:created?'w':'wx'});created=true;};
save(); // Persist the exact protocol and input identity before first sample.
const dir=mkdtempSync(join(tmpdir(),'visibility-controlled-')),entry=join(dir,'vm.mjs');writeFileSync(entry,executable);
try{
 for(let pair=1;pair<=protocol.warmupPairs+protocol.measuredPairs;pair++)for(const side of pair%2?['before','after']:['after','before']){
  const phase=pair<=protocol.warmupPairs?'warmup':'measurement',loadBefore=loadavg(),at=new Date().toISOString(),start=performance.now();
  const result=spawnSync(process.execPath,[entry,side,'--timed'],{encoding:'utf8',timeout:protocol.timeoutMs,maxBuffer:4*1024*1024});
  const sample={phase,pair,side,at,wallMs:performance.now()-start,loadBefore,loadAfter:loadavg(),status:result.status,signal:result.signal,error:result.error?.message??null,stdout:result.stdout,stderr:result.stderr};
  samples.push(sample);save();assert.ifError(result.error);assert.equal(result.status,0,result.stderr);
  assert.match(result.stdout,/RUNTIME_BASELINE_PASS seed=1 idleFrames=300/);assert(!result.stdout.includes('VISIBILITY_GRAPH '));
  const lines=result.stdout.split('\n'),rows=lines.filter(line=>line.startsWith('VISIBILITY_COUNTS ')),cpu=lines.filter(line=>line.startsWith('VISIBILITY_CPU '));assert.equal(rows.length,1);assert.equal(cpu.length,1);
  sample.counts=JSON.parse(rows[0].slice('VISIBILITY_COUNTS '.length));sample.cpu=JSON.parse(cpu[0].slice('VISIBILITY_CPU '.length));
  sample.workloadSha256=hash(lines.filter(line=>!line.startsWith('VISIBILITY_COUNTS ')&&!line.startsWith('VISIBILITY_CPU ')).join('\n'));
  assert.equal(sample.workloadSha256,samples[0].workloadSha256);
  assert.deepEqual(sample.counts,samples.find(s=>s.side===side).counts);
  const idle=sample.counts.find(row=>row.phase==='idle-300');assert.deepEqual(idle.counts,side==='before'?[900,0,3600,7200,0]:[900,0,1800,5400,0]);
  assert.deepEqual(identity(),source,'inputs changed during experiment');save();
 }
 for(let pair=1;pair<=protocol.warmupPairs+protocol.measuredPairs;pair++){
  const [before,after]=['before','after'].map(side=>samples.find(s=>s.pair===pair&&s.side===side));
  assert.deepEqual(before.counts.map(row=>row.phase),after.counts.map(row=>row.phase));
  for(let i=0;i<before.counts.length;i++)for(const index of [0,1,4])assert.equal(before.counts[i].counts[index],after.counts[i].counts[index]);
 }
 const measured=samples.filter(s=>s.phase==='measurement');
 const quantile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1];
 const summary=Object.fromEntries(['before','after'].map(side=>{const rows=measured.filter(s=>s.side===side);return [side,{p50Ms:quantile(rows.map(r=>r.wallMs),.5),p95Ms:quantile(rows.map(r=>r.wallMs),.95),p50CpuMs:quantile(rows.map(r=>(r.cpu.user+r.cpu.system)/1000),.5)}];}));
 const logs=Array.from({length:protocol.measuredPairs},(_,i)=>{const pair=i+protocol.warmupPairs+1;return Math.log(measured.find(s=>s.pair===pair&&s.side==='after').wallMs/measured.find(s=>s.pair===pair&&s.side==='before').wallMs);});
 let state=protocol.bootstrapSeed>>>0;const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
 const bootstrap=Array.from({length:protocol.bootstrapIterations},()=>{let total=0;for(let i=0;i<logs.length;i++)total+=logs[Math.floor(random()*logs.length)];return Math.exp(total/logs.length);});
 const upper95=quantile(bootstrap,.95),ratio=Math.exp(logs.reduce((sum,x)=>sum+x,0)/logs.length);
 report.analysis={summary,pairedGeometricWallRatio:ratio,upperOneSided95:upper95,meetsPredeclaredCriterion:upper95<=1&&summary.after.p50Ms<=summary.before.p50Ms&&summary.after.p95Ms<=summary.before.p95Ms};
 report.completedAt=new Date().toISOString();save();console.log(JSON.stringify(report.analysis));
}catch(error){report.failure=String(error);save();throw error;}finally{rmSync(dir,{recursive:true,force:true});}
