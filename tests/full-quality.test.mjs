import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {fullGateErrors,publishFullQuality,beginFullQuality,main} from '../scripts/publish-full-quality.mjs';
import {currentFullQualityJobs,qualityWorkflowPath} from '../scripts/verify-delivery.mjs';
import {qualityShardJobs} from '../scripts/ci-quality-shape.mjs';
import {beforeAutoMergeWorkflow,beforeExecutionTimeoutWorkflow} from './helpers/auto-merge-workflow.mjs';
const sha=c=>c.repeat(40),repo='CHNISam/Slay-the-Abyss';
function fixture(){return {repo,runId:7,attempt:1,number:510,head:sha('a'),base:sha('b'),tested:sha('d'),mode:'full',
 needs:{impact:{result:'success'},rules:{result:'success'},fast:{result:'skipped'},presentation:{result:'success'},'engineering-posix':{result:'success'}},
 run:{id:7,run_attempt:1,event:'pull_request',head_sha:sha('a'),path:qualityWorkflowPath,status:'in_progress',repository:{full_name:repo},pull_requests:[{number:510}]},
 jobs:currentFullQualityJobs.map((name,i)=>({id:i+100,name,run_id:7,run_attempt:1,head_sha:sha('a'),status:name==='check'?'in_progress':'completed',conclusion:name==='check'?null:name==='fast'?'skipped':'success'})),
 latestRun:{id:7,run_attempt:1},pr:{number:510,state:'open',merged:false,head:{sha:sha('a'),repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},merge_commit_sha:sha('d')},
 target:sha('b'),commit:{sha:sha('d'),parents:[{sha:sha('b')},{sha:sha('a')}]},
 checkout:{schemaVersion:1,attempt:1,runId:7,head:sha('a'),base:sha('b'),tested:sha('d'),event:'pull_request',prNumber:510,parents:[sha('b'),sha('a')]},
 checkoutArtifact:{id:200,name:'quality-7-1-check',expired:false,workflow_run:{id:7,head_sha:sha('a')}}};}
test('Full gate accepts the exact running aggregate only after every actual shard succeeds',()=>assert.deepEqual(fullGateErrors(fixture()),[]));

test('Full publisher cannot certify old 27/28/30/33-job shapes or a forged/missing current actual shard',()=>{
 for(const mutate of [
  ...[[13,9],[14,9],[16,9],[16,12]].map(([windows,posix])=>e=>{
   const win=e.jobs.find(j=>j.name.startsWith('rules (')),linux=e.jobs.find(j=>j.name.startsWith('engineering-posix ('));
   assert(win&&linux,'current matrices supply complete legacy-shape samples');
   e.jobs=e.jobs.filter(j=>!j.name.startsWith('rules (')&&!j.name.startsWith('engineering-posix ('));
   e.jobs.push(...Array.from({length:windows},(_,i)=>({...win,id:1000+i,name:`rules (${i+1}/${windows})`})),...Array.from({length:posix},(_,i)=>({...linux,id:2000+i,name:`engineering-posix (${i+1}/${posix})`})));
  }),
  e=>e.jobs=e.jobs.filter(j=>j.name!=='engineering-posix (13/13)'),
  e=>e.jobs.push({...e.jobs.find(j=>j.name==='engineering-posix (13/13)'),id:3000}),
  e=>e.jobs.find(j=>j.name==='engineering-posix (13/13)').name='engineering-posix (13/12)',
  e=>e.jobs=e.jobs.filter(job=>job.name!=='rules (17/17)'),
  e=>e.jobs.push({...e.jobs.find(job=>job.name==='rules (17/17)'),id:900}),
  e=>e.jobs.find(job=>job.name==='rules (17/17)').id=e.jobs.find(job=>job.name==='rules (16/17)').id,
  e=>e.jobs.push({...e.jobs.find(job=>job.name==='rules (17/17)'),id:3001,name:'rules (18/17)'}),
  e=>e.jobs.find(job=>job.name==='rules (17/17)').name='rules (17/16)',
  e=>{const sample=e.jobs.find(job=>job.name==='rules (1/17)');assert(sample,'actual current first shard exists');e.jobs=e.jobs.filter(job=>!job.name.startsWith('rules ('));e.jobs.push(...Array.from({length:13},(_,i)=>({...sample,id:700+i,name:`rules (${i+1}/13)`})));},
  e=>{e.jobs=e.jobs.filter(job=>job.name!=='rules (17/17)');e.jobTotal=35;e.matrix={windows:17,posix:13};},
  e=>e.checkout.tested=sha('f'),
 ]){
  const e=fixture();assert.equal(e.jobs.length,35);mutate(e);
  assert(fullGateErrors(e).length,String(mutate));let posted;
  const result=publishFullQuality(e,(...args)=>{posted=args.find(arg=>arg.startsWith('state=')).slice(6);return JSON.stringify({state:posted,context:'full-quality'});});
  assert.equal(result.state,'failure');assert.equal(posted,'failure');
 }
});
function inheritedFullReceipt(depth=1){
 const e=fixture();e.attempt=e.run.run_attempt=e.latestRun.run_attempt=depth+1;
 e.jobs.forEach(j=>j.run_attempt=depth+1);
 const first=e.jobs.find(j=>j.name.startsWith('rules (1/'));
 Object.assign(first,{run_attempt:1,created_at:'2026-11-04T02:00:00Z',
  started_at:'2026-11-04T02:01:00Z',completed_at:'2026-11-04T02:02:00Z',
  runner_id:12,runner_name:'Hosted Agent',runner_group_id:0,labels:['windows-2025'],
  steps:[{number:1,name:'Set up job',status:'completed',conclusion:'success',
   started_at:'2026-11-04T02:01:00Z',completed_at:'2026-11-04T02:01:10Z'},
  {number:4,name:'Skipped conditional',status:'completed',conclusion:'skipped',
   started_at:'2026-11-04T02:01:10Z',completed_at:'2026-11-04T02:01:10Z'},
  {number:50,name:'Upload receipt',status:'completed',conclusion:'success',
   started_at:'2026-11-04T02:01:10Z',completed_at:'2026-11-04T02:02:00Z'}]});
 for(let i=1;i<=depth;i++)e.jobs.push({...structuredClone(first),id:600+i,run_attempt:1+i,
  created_at:`2026-11-04T02:0${2+i}:00Z`,runner_group_id:null});
 return e;
}
test('Full publisher shares proven inherited receipt identity without rewriting raw attempts',()=>{
 for(const depth of [1,2]){
  const e=inheritedFullReceipt(depth);e.jobs.reverse();const before=JSON.stringify(e);
  assert.deepEqual(fullGateErrors(e),[]);
  const writes=[];
  assert.equal(publishFullQuality(e,(...args)=>{writes.push(args);return JSON.stringify({state:'success',context:'full-quality'});}).state,'success');
  assert.equal(writes.length,1);assert(writes[0].includes('state=success'));
  assert.equal(JSON.stringify(e),before);
 }
});
test('Full publisher never borrows an ambiguous, failed, different or stale execution receipt',()=>{
 const mutations=[
  (e,a,b)=>e.jobs.splice(e.jobs.indexOf(a),1),
  (e,a,b)=>e.jobs=e.jobs.filter(j=>j.name!==a.name||j.run_attempt!==2),
  (e,a,b)=>e.jobs.push({...a,id:900}),
  (e,a,b)=>b.id=a.id,(e,a,b)=>b.run_id++,(e,a,b)=>b.head_sha=sha('f'),
  (e,a,b)=>b.conclusion='failure',(e,a,b)=>b.status='in_progress',
  (e,a,b)=>a.conclusion='failure',(e,a,b)=>b.steps=[],
  (e,a,b)=>b.steps[0].name='Different execution',
  (e,a,b)=>b.runner_id++,(e,a,b)=>b.created_at='invalid',
  (e,a,b)=>Object.assign(b,{created_at:'2026-11-04T03:00:00Z',started_at:'2026-11-04T03:01:00Z',completed_at:'2026-11-04T03:02:00Z'}),
  e=>e.checkout.attempt=e.attempt,e=>e.checkoutArtifact.name=`quality-7-${e.attempt}-check`,
  e=>e.checkoutArtifact.expired=true,e=>e.checkout.head=sha('f'),
  e=>e.checkout.base=sha('f'),e=>e.checkout.tested=sha('f'),e=>e.checkout.parents.reverse(),
  e=>e.latestRun.run_attempt++,
 ];
 for(const mutate of mutations){
  const e=inheritedFullReceipt(2),first=e.jobs.find(j=>j.name.startsWith('rules (1/'));
  mutate(e,first,e.jobs.at(-1));assert(fullGateErrors(e).length,String(mutate));
  let state;const result=publishFullQuality(e,(...args)=>{state=args.find(a=>a.startsWith('state=')).slice(6);return JSON.stringify({state,context:'full-quality'});});
  assert.notEqual(result.state,'success');assert.notEqual(state,'success');
 }
});
test('real Full entrypoint collects and publishes inherited receipt with only the current aggregate running',()=>{
 for(const missingPrior of [false,true]){
  const e=inheritedFullReceipt(),dir=mkdtempSync(join(tmpdir(),'inherited-full-event-')),eventPath=join(dir,'event.json'),writes=[],downloads=[];
  if(missingPrior)e.jobs=e.jobs.filter(j=>j.name!==qualityShardJobs[0]||j.run_attempt!==1);
  writeFileSync(eventPath,JSON.stringify({pull_request:e.pr}));
  const env={GITHUB_EVENT_PATH:eventPath,GITHUB_EVENT_NAME:'pull_request',GITHUB_REPOSITORY:repo,
   GITHUB_SHA:e.tested,GITHUB_RUN_ID:'7',GITHUB_RUN_ATTEMPT:'2',FULL_MODE:e.mode,FULL_NEEDS:JSON.stringify(e.needs)};
  const query=(...args)=>{
   const endpoint=args.at(-1);
   if(args.includes('POST')){const state=args.find(a=>a.startsWith('state=')).slice(6);writes.push(state);return JSON.stringify({state,context:'full-quality'});}
   if(args[0]==='run'){
    downloads.push(args);assert.equal(args[args.indexOf('--name')+1],'quality-7-1-check');
    writeFileSync(join(args[args.indexOf('--dir')+1],'ci-checkout.json'),JSON.stringify(e.checkout));return '';
   }
   if(endpoint.endsWith('/actions/runs/7'))return JSON.stringify(e.run);
   if(endpoint.includes('/jobs?'))return JSON.stringify([{jobs:e.jobs}]);
   if(endpoint.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[e.run]}]);
   if(endpoint.includes('/artifacts?'))return JSON.stringify([{artifacts:[e.checkoutArtifact]}]);
   if(endpoint.endsWith('/artifacts/200'))return JSON.stringify(e.checkoutArtifact);
   if(endpoint.endsWith('/pulls/510'))return JSON.stringify(e.pr);
   if(endpoint.endsWith('/git/ref/heads/develop'))return JSON.stringify({object:{sha:e.target}});
   if(endpoint.endsWith('/commits/'+e.tested))return JSON.stringify(e.commit);
   throw Error('Unexpected query '+endpoint);
  };
  try{
   if(missingPrior){assert.throws(()=>main(env,query),/receipt|artifact|execution/i);assert.deepEqual(writes,['failure']);assert.equal(downloads.length,0);}
   else{main(env,query);assert.deepEqual(writes,['success']);assert.equal(downloads.length,1);}
  }finally{rmSync(dir,{recursive:true,force:true});}
 }
});
test('Full gate rejects Fast, missing, failed, cancelled and skipped dependencies',()=>{
 for(const mutate of [f=>f.mode='fast',f=>delete f.needs.rules,
  ...['failure','cancelled','skipped'].map(value=>f=>f.needs['engineering-posix'].result=value),
  f=>f.jobs.pop(),f=>f.jobs.find(j=>j.name.startsWith('rules')).conclusion='skipped',
  f=>f.jobs.find(j=>j.name.startsWith('engineering-posix (')).status='queued',
  f=>f.jobs.push({...f.jobs[2],id:999,run_attempt:2,conclusion:'failure'})]){
  const f=fixture();mutate(f);assert(fullGateErrors(f).length,String(mutate));
 }
});
test('Full gate rejects stale run, attempt, head, target and merge parent identity',()=>{
 for(const mutate of [f=>f.latestRun.id=8,f=>f.latestRun.run_attempt=2,f=>f.run.event='push',
  f=>f.pr.head.sha=sha('c'),f=>f.target=sha('c'),f=>f.pr.base.ref='master',
  f=>f.commit.parents.reverse(),f=>f.commit.parents.push({sha:sha('c')}),f=>f.jobs[0].head_sha=sha('c')]){
  const f=fixture();mutate(f);assert(fullGateErrors(f).length,String(mutate));
 }
});
test('Full success requires the actual immutable receipt, not merely green job metadata',()=>{
 for(const mutate of [f=>delete f.checkout,f=>delete f.checkoutArtifact,f=>f.checkout.prNumber=511,
  f=>f.checkout.base=sha('c'),f=>f.checkout.tested=sha('c'),f=>f.checkout.parents.reverse(),
  f=>f.checkout.attempt=2,f=>f.checkoutArtifact.expired=true,f=>f.checkoutArtifact.workflow_run.head_sha=sha('c')]){
  const f=fixture();mutate(f);let state;
  assert.equal(publishFullQuality(f,(...args)=>{state=args.find(a=>a.startsWith('state=')).slice(6);return JSON.stringify({state,context:'full-quality'});}).state,'failure');
  assert.equal(state,'failure');
 }
});
test('publisher posts failure for invalid evidence and never hides a transport failure',()=>{
 const f=fixture(),writes=[];f.mode='fast';
 const result=publishFullQuality(f,(...args)=>{writes.push(args);return JSON.stringify({state:'failure',context:'full-quality'});});
 assert.equal(result.state,'failure');assert(writes[0].includes('state=failure'));
 assert.throws(()=>publishFullQuality(f,()=>{throw Error('transport unavailable');}),/transport unavailable/);
});
test('publisher binds success to reviewed head and current run URL and verifies response',()=>{
 const f=fixture(),writes=[];
 assert.equal(publishFullQuality(f,(...args)=>{writes.push(args);return JSON.stringify({state:'success',context:'full-quality'});}).state,'success');
 assert(writes[0].includes(`repos/${repo}/statuses/${f.head}`));assert(writes[0].includes(`target_url=https://github.com/${repo}/actions/runs/7`));
 assert.throws(()=>publishFullQuality(f,()=>JSON.stringify({state:'pending',context:'full-quality'})),/readback/);
});
test('superseded planner and aggregate never overwrite a newer run or attempt status',()=>{
 for(const mutate of [f=>f.latestRun.id=8,f=>f.latestRun.run_attempt=2]){
  const f=fixture();mutate(f);let writes=0;const query=()=>{writes++;throw Error('stale writer must not run');};
  assert.equal(beginFullQuality(f,query).state,'superseded');
  assert.equal(publishFullQuality(f,query).state,'superseded');assert.equal(writes,0);
 }
 const f=fixture(),writes=[];
 assert.equal(beginFullQuality(f,(...args)=>{writes.push(args);return JSON.stringify({state:'pending',context:'full-quality'});}).state,'pending');
 assert(writes[0].includes('state=pending'));
});
function mainFixture(change,check){
 const f=fixture();change(f);
 const dir=mkdtempSync(join(tmpdir(),'full-quality-event-')),eventPath=join(dir,'event.json');
 writeFileSync(eventPath,JSON.stringify({pull_request:f.pr}));
 const env={GITHUB_EVENT_PATH:eventPath,GITHUB_EVENT_NAME:'pull_request',GITHUB_REPOSITORY:repo,
  GITHUB_SHA:f.tested,GITHUB_RUN_ID:'7',GITHUB_RUN_ATTEMPT:'1',FULL_MODE:f.mode,FULL_NEEDS:JSON.stringify(f.needs)};
 try{check(f,env);}finally{rmSync(dir,{recursive:true,force:true});}
}
test('real publisher entrypoint preserves master and fork flows without status writes or API queries',()=>{
 for(const change of [f=>f.pr.base.ref='master',f=>f.pr.head.repo.full_name='someone/fork'])mainFixture(change,(_f,env)=>{
  for(const pending of [false,true])assert.doesNotThrow(()=>main(env,()=>{throw Error('not a develop same-repo publisher');},{pending}));
 });
});
test('real publisher entrypoint collects API identities before current pending and success publication',()=>{
 mainFixture(()=>{},(f,env)=>{
  for(const pending of [true,false]){
   const writes=[],query=(...args)=>{
    const endpoint=args.at(-1);
    if(args.includes('POST')){writes.push(args);return JSON.stringify({state:pending?'pending':'success',context:'full-quality'});}
    if(endpoint.endsWith('/actions/runs/7'))return JSON.stringify(f.run);
    if(endpoint.includes('/jobs?'))return JSON.stringify([{jobs:f.jobs}]);
    if(endpoint.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[f.run]}]);
    if(endpoint.endsWith('/pulls/510'))return JSON.stringify(f.pr);
    if(endpoint.endsWith('/git/ref/heads/develop'))return JSON.stringify({object:{sha:f.target}});
    if(endpoint.endsWith('/commits/'+f.tested))return JSON.stringify(f.commit);
    throw Error('Unexpected API query '+endpoint);
   };
   main(env,query,{pending,loadCheckout:()=>({checkout:f.checkout,checkoutArtifact:f.checkoutArtifact})});assert.equal(writes.length,1);
  }
 });
});
test('Full publication reuses existing jobs and grants status writes only to planner and final aggregate',()=>{
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const jobs=[...workflow.slice(workflow.indexOf('\njobs:\n')).matchAll(/^  ([\w-]+):\n([\s\S]*?)(?=^  [\w-]+:|(?![\s\S]))/gm)];
 assert.deepEqual(jobs.map(j=>j[1]),['impact','fast','rules','check','presentation','engineering-posix-shards','engineering-posix']);
 for(const [,name,body]of jobs){
  if(['impact','check'].includes(name))assert.match(body,/^    permissions:\n      contents: read\n      actions: read\n      pull-requests: read\n      statuses: write$/m);
  else assert.doesNotMatch(body,/statuses: write|contents: write|pull-requests: write|checks: write/);
 }
 assert.match(workflow,/^permissions:\n  contents: read$/m);
 assert.match(jobs.find(j=>j[1]==='check')[2],/^    needs: \[impact, rules, fast, presentation, engineering-posix\]$/m);
});
test('reviewed workflow inverse rejects partial wiring and preserves original arbitrary source drift',()=>{
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const before=beforeAutoMergeWorkflow(workflow);assert.equal(typeof before,'string');assert(!before.includes('full-quality'));
 for(const drift of [workflow.replace('statuses: write','statuses: read'),
  workflow.replace('run: node scripts/publish-full-quality.mjs','run: echo forged'),
  workflow.replace('fast, presentation, engineering-posix]','fast]')])assert.equal(beforeAutoMergeWorkflow(drift),null);
 const drift=workflow.replace('timeout-minutes: 30','timeout-minutes: 31');
 const projected=beforeAutoMergeWorkflow(drift);
 assert(projected===null||projected.includes('timeout-minutes: 31'),'unrelated regression must remain visible or fail closed');
});

test('execution slack restores only the complete approved workflow edit for historical guards',()=>{
 const current=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 for(const eol of ['\n','\r\n']){
  const source=current.replaceAll('\n',eol),old=beforeExecutionTimeoutWorkflow(source);
  assert.notEqual(old,source);
  assert.ok(old.includes("75 || 30 }}"));
  assert.ok(old.includes('runs-on: ubuntu-24.04'+eol+'    timeout-minutes: 20'));
  for(const drift of [source.replace('75 || 45','75 || 46'),
   source.replace('timeout-minutes: 30','timeout-minutes: 31'),
   source.replace('if: ${{ !cancelled() }}','if: success()'),
   source.replace('Files execute once.','Files execute twice.')])
   assert.equal(beforeExecutionTimeoutWorkflow(drift),drift,'partial or unreviewed edit remains visible');
  const drift=source.replace('contents: read','contents: write');
  assert.ok(beforeExecutionTimeoutWorkflow(drift).includes('contents: write'));
  assert.equal((old.match(/^    if: always\(\)$/gm)??[]).length,2,'restore both original summary guards only');
 }
});
