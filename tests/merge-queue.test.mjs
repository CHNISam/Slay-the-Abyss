import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {queueEventErrors,queueFullErrors,main} from '../scripts/publish-merge-group.mjs';
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

test('native queue rejects old 13/9 green jobs, missing rules14, duplicates and forged totals or source receipts',()=>{
 for(const mutate of [
  e=>e.jobs=e.jobs.filter(job=>job.name!=='rules (14/14)'),
  e=>e.jobs.push({...e.jobs.find(job=>job.name==='rules (14/14)'),id:900}),
  e=>e.jobs.find(job=>job.name==='rules (14/14)').id=e.jobs.find(job=>job.name==='rules (13/14)').id,
  e=>e.jobs.find(job=>job.name==='rules (14/14)').name='rules (14/13)',
  e=>{const sample=e.jobs.find(job=>job.name==='rules (1/14)');e.jobs=e.jobs.filter(job=>!job.name.startsWith('rules ('));e.jobs.push(...Array.from({length:13},(_,i)=>({...sample,id:700+i,name:`rules (${i+1}/13)`})));},
  e=>{e.jobs=e.jobs.filter(job=>job.name!=='rules (14/14)');e.jobTotal=28;e.event.merge_group.matrix={windows:14,posix:9};},
  e=>e.checkout.checkout.head=sha('f'),
 ]){
  const e=fixture();assert.equal(e.jobs.length,28);mutate(e);
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
  assert.deepEqual(writes.map(w=>w.state),['pending','pending']);
  const result=main(f.env,query,{loadCheckout});
  assert.equal(result.state,'success');
  assert.deepEqual(writes.map(w=>w.context),['full-quality','independent-review','full-quality','independent-review']);
  const g=fixture();g.needs.rules.result='failure';
  f.env.FULL_NEEDS=JSON.stringify(g.needs);
  assert.throws(()=>main(f.env,query,{loadCheckout}),/Full/);
  assert.equal(writes.length,4,'failure cannot release any further status');
 }finally{rmSync(dir,{recursive:true,force:true});}
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
