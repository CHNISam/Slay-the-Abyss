import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {queueEventErrors,queueFullErrors,statusWriteResponse,main} from '../scripts/publish-merge-group.mjs';
import {currentFullQualityJobs,qualityWorkflowPath} from '../scripts/verify-delivery.mjs';
import {impact} from '../scripts/ci-impact.mjs';
import {beforeNativeMergeQueueWorkflow} from './helpers/merge-queue-workflow.mjs';
import {admissionFixture,admissionQuery} from './helpers/merge-queue-admission.mjs';

const sha=c=>c.repeat(40),repo='FurinyaWorks/Slay-the-Abyss';
function fixture(){
 const head=sha('a'),base=sha('b'),ref='refs/heads/gh-readonly-queue/develop/pr-510-a';
 const env={GITHUB_EVENT_NAME:'merge_group',GITHUB_REPOSITORY:repo,GITHUB_REF:ref,GITHUB_SHA:head,
  GITHUB_RUN_ID:'7',GITHUB_RUN_ATTEMPT:'1',FULL_MODE:'full',FULL_NEEDS:''};
 const event={action:'checks_requested',repository:{full_name:repo},
  merge_group:{head_sha:head,base_sha:base,base_ref:'refs/heads/develop',head_ref:ref}};
 const needs={impact:{result:'success'},rules:{result:'success'},fast:{result:'skipped'},
  presentation:{result:'success'},'engineering-posix':{result:'success'}};
 const ruleset={target:'branch',enforcement:'active',bypass_actors:[],
  conditions:{ref_name:{include:['refs/heads/develop'],exclude:[]}},
  rules:[{type:'merge_queue',parameters:{merge_method:'SQUASH',grouping_strategy:'ALLGREEN'}},{type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,required_status_checks:
   ['check','presentation','engineering-posix','inventory','full-quality','independent-review']
    .map(context=>({context,integration_id:context==='independent-review'?null:15368}))}},
   {type:'pull_request',parameters:{allowed_merge_methods:['squash'],required_review_thread_resolution:true}},
   {type:'required_linear_history'}]};
 const run={id:7,run_attempt:1,event:'merge_group',head_sha:head,status:'in_progress',path:qualityWorkflowPath,repository:{full_name:repo}};
 const jobs=currentFullQualityJobs.map((name,i)=>({name,id:100+i,run_id:7,run_attempt:1,head_sha:head,
  status:name==='check'?'in_progress':'completed',
  conclusion:name==='check'?null:name==='fast'?'skipped':'success'}));
 const checkout={checkout:{schemaVersion:1,event:'merge_group',runId:7,attempt:1,tested:head,head,base,parents:[base]},
  checkoutArtifact:{id:42,name:'quality-7-1-check',expired:false,workflow_run:{id:7,head_sha:head}}};
 return {event,env,needs,ruleset,run,latest:run,jobs,checkout};
}
test('merge group is a genuine develop queue event, not a PR, push or forged ref',()=>{
 const f=fixture();
 assert.deepEqual(queueEventErrors(f.event,f.env),[]);
 for(const mutate of [
  x=>x.env.GITHUB_EVENT_NAME='pull_request',x=>x.event.action='enqueued',
  x=>x.event.repository.full_name='someone/else',x=>x.env.GITHUB_REPOSITORY='someone/else',
  x=>x.env.GITHUB_SHA=sha('c'),x=>x.env.GITHUB_REF='refs/heads/develop',
  x=>x.event.merge_group.base_ref='refs/heads/master',
  x=>x.event.merge_group.base_sha='bad',
  x=>x.event.merge_group.head_ref='refs/heads/develop']) {
  const v=fixture();mutate(v);assert(queueEventErrors(v.event,v.env).length,String(mutate));
 }
});
test('queue full requires every shard, immutable receipt and actual native admission policy',()=>{
 assert.deepEqual(queueFullErrors(fixture()),[]);
 for(const mutate of [
  x=>x.env.FULL_MODE='fast',x=>x.needs.fast.result='success',
  x=>x.needs.rules.result='skipped',x=>x.needs.presentation.result='failure',
  x=>x.ruleset.rules=x.ruleset.rules.filter(r=>r.type!=='merge_queue'),
  x=>x.ruleset.bypass_actors=[{actor_id:1}],x=>delete x.ruleset.bypass_actors,
  x=>x.ruleset.bypass_actors=null,x=>x.ruleset.enforcement='disabled',
  x=>x.ruleset.conditions.ref_name.exclude=['refs/heads/develop'],
  x=>x.ruleset.rules[1].parameters.required_status_checks.pop(),
  x=>x.ruleset.rules[1].parameters.required_status_checks[0].integration_id=null,
  x=>x.run.head_sha=sha('c'),x=>x.latest.run_attempt=2,
  x=>x.jobs.pop(),x=>x.jobs.find(j=>j.name.startsWith('rules')).conclusion='failure',
  x=>x.jobs.find(j=>j.name==='check').status='completed',
  x=>x.jobs[1].head_sha=sha('c'),
  x=>x.jobs.push({...x.jobs[0],id:999}),
  x=>x.checkout.checkout.tested=sha('c'),
  x=>x.checkout.checkout.base=sha('c'),
  x=>x.checkout.checkout.event='pull_request',
  x=>x.checkout.checkoutArtifact=null
 ]){
  const f=fixture();mutate(f);assert(queueFullErrors(f).length,String(mutate));
 }
});

test('native queue rejects old 13/9, 14/9, 16/9 or 16/12 green jobs, missing rules17 or POSIX13, duplicates and forged totals or source receipts',()=>{
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
  e=>e.jobs.push({...e.jobs.find(job=>job.name==='rules (17/17)'),id:3001,name:'rules (18/17)'}),
  e=>e.jobs.find(job=>job.name==='rules (17/17)').id=e.jobs.find(job=>job.name==='rules (16/17)').id,
  e=>e.jobs.find(job=>job.name==='rules (17/17)').name='rules (17/16)',
  e=>{const sample=e.jobs.find(job=>job.name==='rules (1/17)');assert(sample,'actual current first shard exists');e.jobs=e.jobs.filter(job=>!job.name.startsWith('rules ('));e.jobs.push(...Array.from({length:13},(_,i)=>({...sample,id:700+i,name:`rules (${i+1}/13)`})));},
  e=>{e.jobs=e.jobs.filter(job=>job.name!=='rules (17/17)');e.jobTotal=35;e.event.merge_group.matrix={windows:17,posix:13};},
  e=>e.checkout.checkout.head=sha('f'),
 ]){
  const e=fixture();assert.equal(e.jobs.length,35);mutate(e);
  assert(queueFullErrors(e).length,String(mutate));
 }
});
test('publisher writes pending first and only releases both contexts after exact Full evidence',()=>{
 const f=admissionFixture(),dir=mkdtempSync(join(tmpdir(),'merge-group-test-'));
 const path=join(dir,'event.json');writeFileSync(path,JSON.stringify(f.event));
 f.env.GITHUB_EVENT_PATH=path;f.env.FULL_NEEDS=JSON.stringify(f.needs);
 const writes=[];
 const query=admissionQuery(f,writes);
 const loadCheckout=()=>({checkout:f.checkout,checkoutArtifact:f.artifact});
 try {
  assert.equal(main(f.env,query,{pending:true}).state,'pending');
  assert.deepEqual(writes.map(w=>w.state),['pending','pending','pending']);
  const result=main(f.env,query,{loadCheckout});
  assert.equal(result.state,'success');
  assert.deepEqual(writes.map(w=>w.context),['full-quality','independent-review','pr-quality','full-quality','independent-review','pr-quality']);
  const g=fixture();g.needs.rules.result='failure';
  f.env.FULL_NEEDS=JSON.stringify(g.needs);
  assert.throws(()=>main(f.env,query,{loadCheckout}),/Full/);
  assert.equal(writes.length,6,'failure cannot release any further status');
 }finally{rmSync(dir,{recursive:true,force:true});}
});

function statusTransportFixture({state='pending',faults=1,committed=false,readback={},newerReadback,mutate,onAttempt,onRead,emptyBody=false,fault}={}){
 const f=admissionFixture(),dir=mkdtempSync(join(tmpdir(),'queue-status-transport-'));
 const eventPath=join(dir,'event.json');writeFileSync(eventPath,JSON.stringify(f.event));f.env.GITHUB_EVENT_PATH=eventPath;
 const writes=[],attempts=[],waits=[],reads=[];let status;
 const base=admissionQuery(f,writes),context=state==='pending'?'independent-review':'full-quality';
 const query=(...args)=>{
  const endpoint=args.find(a=>typeof a==='string'&&a.startsWith('repos/'))??'';
  if(args.includes('POST')){
   const name=args.find(a=>a.startsWith('context=')).slice(8),value=args.find(a=>a.startsWith('state=')).slice(6);
   if(name===context&&value===state){
    attempts.push(args);onAttempt?.(attempts.length);
    if(attempts.length<=faults){
     if(committed){status={id:701,context,state,description:args.find(a=>a.startsWith('description=')).slice(12),creator:{id:41898282,login:'github-actions[bot]'},
      target_url:`https://github.com/${repo}/actions/runs/7`,...readback};writes.push({context,state});}
     mutate?.(f);
     if(emptyBody)return '';
     throw fault??Error('Merge Queue GitHub API failed: unexpected end of JSON input');
    }
   }
  }
  if(endpoint.includes(`/commits/${f.env.GITHUB_SHA}/statuses?`)){
   reads.push(args);onRead?.(f);return JSON.stringify([status?[status,...(newerReadback?[{...status,id:702,...newerReadback}]:[])]:[]]);
  }
  return base(...args);
 };
 return {f,writes,attempts,waits,reads,query,
  run:()=>main(f.env,query,{pending:state==='pending',loadCheckout:()=>({checkout:f.checkout,checkoutArtifact:f.artifact}),wait:ms=>waits.push(ms)}),
  cleanup:()=>{assert(dir.startsWith(join(tmpdir(),'queue-status-transport-')));rmSync(dir,{recursive:true,force:true});}};
}

test('a lost pending POST response is accepted only from exact latest Actions/head/context/run/state readback',()=>{
 const m=statusTransportFixture({committed:true});try{
  assert.equal(m.run().state,'pending');assert.equal(m.attempts.length,1);
  assert.equal(m.reads.length,1);assert.equal(m.waits.length,0);
  assert.deepEqual(m.writes.map(w=>w.context),['full-quality','independent-review','pr-quality']);
 }finally{m.cleanup();}
});
test('an uncommitted empty POST response retries only that context with bounded waiting',()=>{
 const m=statusTransportFixture();try{
  assert.equal(m.run().state,'pending');assert.equal(m.attempts.length,2);
  assert.equal(m.reads.length,1);assert.deepEqual(m.waits,[250]);
  assert.deepEqual(m.writes.map(w=>w.context),['full-quality','independent-review','pr-quality']);
 }finally{m.cleanup();}
});
test('a transient HTTP503 retries only the failed status and preserves normal Full gates',()=>{
 const m=statusTransportFixture({fault:Object.assign(Error('Queue status response unavailable'),{httpStatus:503})});try{
  assert.equal(m.run().state,'pending');assert.equal(m.attempts.length,2);assert.deepEqual(m.waits,[250]);
 }finally{m.cleanup();}
});
test('three uncertain status writes fail closed without starting an unbounded retry loop',()=>{
 const m=statusTransportFixture({faults:99});try{
  assert.throws(m.run,/status.*(uncertain|unavailable|failed)/i);assert.equal(m.attempts.length,3);
  assert.deepEqual(m.waits,[250,500]);assert.equal(m.reads.length,3);
  assert.deepEqual(m.writes,[{context:'full-quality',state:'pending'}]);
 }finally{m.cleanup();}
});
test('every HTTP4xx including 408/429 stops without retrying or borrowing an older status',()=>{
 for(const code of [400,401,403,408,429]){
 const m=statusTransportFixture();let attempts=0;
 const query=(...args)=>{
  if(args.includes('POST')&&args.includes('context=independent-review')){attempts++;throw Object.assign(Error('HTTP '+code),{httpStatus:code});}
  return m.query(...args);
 };
 try{
  assert.throws(()=>main(m.f.env,query,{pending:true,wait:ms=>m.waits.push(ms)}),new RegExp(String(code)));
  assert.equal(attempts,1);assert.equal(m.reads.length,0);assert.deepEqual(m.waits,[]);
 }finally{m.cleanup();}
 }
});
test('a lost write cannot borrow a foreign Actions source, run, context, state or older status',()=>{
 for(const readback of [
  {creator:{id:1,login:'someone'}},{creator:{id:41898282,login:'someone'}},
  {target_url:`https://github.com/${repo}/actions/runs/6`},{context:'full-quality'},{state:'success'},
  {description:'Awaiting verified native merge group Full [attempt:0]'},
 ]){
  const m=statusTransportFixture({faults:99,committed:true,readback});try{
   assert.throws(m.run,/status.*(uncertain|unavailable|failed)/i);assert.equal(m.attempts.length,3);
  }finally{m.cleanup();}
 }
 const m=statusTransportFixture({faults:99,committed:true,newerReadback:{state:'failure'}});try{
  assert.throws(m.run,/status.*unavailable/i);assert.equal(m.attempts.length,3,'latest context failure supersedes old matching success');
 }finally{m.cleanup();}
});
test('success transport recovery revalidates the current attempt and complete queue admission',()=>{
 const m=statusTransportFixture({state:'success',committed:true});try{
  assert.equal(m.run().state,'success');assert.equal(m.attempts.length,1);assert.equal(m.reads.length,1);
  assert.deepEqual(m.writes.map(w=>w.context),['full-quality','independent-review','pr-quality']);
 }finally{m.cleanup();}
 for(const mutate of [
  f=>{f.run.status='completed';f.run.conclusion='cancelled';},f=>f.run.run_attempt++,
  f=>f.pr.labels.push({name:'hold'}),f=>f.review.description+=' stale',
 ]){
  const stale=statusTransportFixture({state:'success',mutate});try{
   assert.throws(stale.run,/run|attempt|authoriz|eligible|paused|Full/i);
   assert.equal(stale.attempts.length,1,'stale authorization must not be posted again');
   assert.equal(stale.writes.length,0,'no later success context may release a stale group');
  }finally{stale.cleanup();}
 }
});
test('pending recovery accepts a genuinely queued run but refuses cancelled or newer attempts',()=>{
 const queued=statusTransportFixture({committed:true});try{
  queued.f.run.status='queued';assert.equal(queued.run().state,'pending');assert.equal(queued.attempts.length,1);
 }finally{queued.cleanup();}
 for(const mutate of [f=>f.run.run_attempt++,f=>{f.run.status='completed';f.run.conclusion='cancelled';}]){
  const m=statusTransportFixture({mutate});try{assert.throws(m.run,/run\/attempt/);assert.equal(m.attempts.length,1);}
  finally{m.cleanup();}
 }
});
test('an empty raw JSON response follows the same bounded recovery and rechecks after accepted readback',()=>{
 const empty=statusTransportFixture({committed:true,emptyBody:true});try{
  assert.equal(empty.run().state,'pending');assert.equal(empty.attempts.length,1);
 }finally{empty.cleanup();}
 const stale=statusTransportFixture({state:'success',committed:true,onRead:f=>{f.run.status='completed';f.run.conclusion='cancelled';}});
 try{assert.throws(stale.run,/run\/attempt/);assert.equal(stale.attempts.length,1);assert.equal(stale.writes.length,1);}
 finally{stale.cleanup();}
});
test('status HTTP diagnostics retain status/request-id and never raw authenticated headers or error bodies',()=>{
 const diagnostic=[],identity={context:'independent-review',state:'pending'},body=JSON.stringify(identity);
 const response=statusWriteResponse({status:0,stdout:'HTTP/1.1 100 Continue\r\n\r\nHTTP/2.0 201 Created\r\nX-GitHub-Request-Id: AB12:CD34\r\nAuthorization: Bearer secret-header\r\n\r\n'+body},identity,item=>diagnostic.push(item));
 assert.equal(response,body);assert.deepEqual(diagnostic,[{event:'queue_status_http',...identity,httpStatus:201,requestId:'AB12:CD34',exitCode:0}]);
 for(const [status,stdout,stderr,retryable,httpStatus]of [
  [1,'HTTP/2.0 503 Service Unavailable\r\nX-GitHub-Request-Id: RETRY:1\r\n\r\n{"message":"secret-body"}','secret-stderr',true,503],
  [1,'HTTP/2.0 403 Forbidden\r\n\r\n{}','unexpected end of JSON input secret-stderr',false,403],
  [1,'HTTP/2.0 201 Created\r\n\r\n','unexpected end of JSON input secret-stderr',true,201],
  [0,'','',true,undefined],
 ]){
  assert.throws(()=>statusWriteResponse({status,stdout,stderr},identity,item=>diagnostic.push(item)),error=>
   error.retryable===retryable&&error.httpStatus===httpStatus&&!/secret/.test(error.message));
 }
 assert(!/secret/.test(JSON.stringify(diagnostic)));
});
test('queue reuses existing Full matrix, never selects Fast, and preserves PR/push paths',()=>{
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const licenses=readFileSync('.github/workflows/licenses.yml','utf8').replaceAll('\r\n','\n');
 for(const s of [workflow,licenses])assert.match(s,/  merge_group:\n    types: \[checks_requested\]\n    branches: \[develop\]/);
 assert.match(workflow,/run: node scripts\/publish-merge-group\.mjs --pending/);
 assert.match(workflow,/run: node scripts\/publish-merge-group\.mjs\n/);
 assert.match(workflow,/run: node scripts\/publish-full-quality\.mjs\n/);
 assert.match(workflow,/^  check:\n[\s\S]*?    needs: \[impact, rules, fast, presentation, engineering-posix\]/m);
 assert.match(licenses,/^  inventory:\n/m);
 assert.equal(impact([],{}, {eventName:'merge_group',base:'develop',forceFull:false},{}).mode,'full');
 assert.equal(impact([],{}, {eventName:'push',base:'develop',forceFull:false},{}).mode,'full');
 assert.equal(impact(['docs/CI.md'],{}, {eventName:'pull_request',base:'develop',forceFull:false},{}).mode,'fast');
});

test('historical Quality projection preserves exact LF and CRLF sources',()=>{
 const live=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const old=beforeNativeMergeQueueWorkflow(live);
 assert.equal(typeof old,'string');
 assert(!old.includes('  merge_group:'));
 assert(!old.includes('publish-merge-group.mjs'));
 assert(!old.includes('github.event.merge_group.base_sha'));
 for(const eol of ['\n','\r\n']) {
  const source=live.replaceAll('\n',eol),expected=old.replaceAll('\n',eol);
  assert.equal(beforeNativeMergeQueueWorkflow(source),expected,'only the reviewed additions may be removed');
  assert.equal(beforeNativeMergeQueueWorkflow(expected),expected,'frozen source bytes remain unchanged');
  const drift=source.replace('timeout-minutes: 3','timeout-minutes: 99');
  assert.equal(beforeNativeMergeQueueWorkflow(drift),expected.replace('timeout-minutes: 3','timeout-minutes: 99'),
   'unrelated changes stay visible to the frozen hash guards');
 }
});
test('historical Quality projection rejects partial or changed queue wiring in LF and CRLF',()=>{
 const live=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 for(const eol of ['\n','\r\n'])for(const drift of [
  live.replace('run: node scripts/publish-merge-group.mjs --pending','run: echo skip'),
  live.replace('run: node scripts/publish-merge-group.mjs\n','run: echo skip\n'),
  live.replace('branches: [develop]\n  push:', 'branches: [master]\n  push:'),
  live.replace('  merge_group:\n','  merge_group:\n  merge_group:\n'),
  live.replace('github.event.merge_group.base_sha || ','')
 ]){
  assert.equal(beforeNativeMergeQueueWorkflow(drift.replaceAll('\n',eol)),null,
   'partial, duplicated or changed queue wiring must stay visible');
 }
});
