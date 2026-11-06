import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {currentFastQualityJobs,fastQualityJobErrors,prFastErrors,collectFastCheckout} from '../scripts/pr-quality-evidence.mjs';
import {main as publishPrQuality} from '../scripts/publish-pr-quality.mjs';
import {armAutoMerge,requiredContexts,reviewContext} from '../scripts/arm-auto-merge.mjs';
import {collectPrDelivery,collectMergedDelivery,verifyDelivery,verifyAutoMergeArm,verifyMergedDelivery,checkoutReceipt,currentFullQualityJobs} from '../scripts/verify-delivery.mjs';
import {projectRepositoryId} from '../scripts/repository-identity.mjs';

const sha=c=>c.repeat(40),repo='FurinyaWorks/Slay-the-Abyss';
function fixture() {
 const e={repo,number:531,runId:7,attempt:1,head:sha('a'),base:sha('b'),tested:sha('c'),
  run:{id:7,run_attempt:1,head_sha:sha('a'),event:'pull_request',path:'.github/workflows/quality.yml',
   status:'completed',conclusion:'success',repository:{full_name:repo},pull_requests:[{number:531}]},
  latestRun:{id:7,run_attempt:1},pr:{number:531,state:'open',merged:false,draft:false,labels:[],
   head:{sha:sha('a'),repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},merge_commit_sha:sha('c')},
  target:sha('b'),commit:{sha:sha('c'),parents:[{sha:sha('b')},{sha:sha('a')}]},
  jobs:currentFastQualityJobs.map((name,i)=>({id:100+i,name,run_id:7,run_attempt:1,head_sha:sha('a'),
   status:'completed',conclusion:['rules','engineering-posix-shards'].includes(name)?'skipped':'success'})),
  checkout:{schemaVersion:1,event:'pull_request',runId:7,attempt:1,head:sha('a'),base:sha('b'),tested:sha('c'),prNumber:531,parents:[sha('b'),sha('a')]},
  checkoutArtifact:{id:300,name:'quality-7-1-fast',expired:false,workflow_run:{id:7,head_sha:sha('a')}},
  plan:{mode:'fast',sha:sha('c'),head:sha('a'),base:sha('b'),runId:7,attempt:1,changed:['scripts/value.mjs'],
   js:['tests/value.test.mjs'],lua:[],reason:'Complete affected set'},
 };
 return e;
}
test('Fast proof accepts two actual platform executions and exact immutable source/plan identities',()=>{
 assert.deepEqual(prFastErrors(fixture()),[]);
 const e=fixture();e.jobs.reverse();assert.deepEqual(prFastErrors(e),[]);
});

test('Fast checkout retains the real merge parents needed by its immutable receipt',()=>{
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const fast=workflow.match(/^  fast:\n([\s\S]*?)(?=^  rules:)/m)?.[1];
 assert.match(fast,/uses: actions\/checkout@[^\n]+\n        with:\n          fetch-depth: 2\n          persist-credentials: false/);
 for(const name of ['rules','engineering-posix-shards'])
  assert(workflow.includes("needs.impact.outputs.mode == 'fast' && '"+name+"' || format("),'Fast skipped matrix name is explicit: '+name);
});
test('only the current aggregate may still be running while publishing its status',()=>{
 const e=fixture();e.run.status='in_progress';e.run.conclusion=null;
 Object.assign(e.jobs.find(j=>j.name==='check'),{status:'in_progress',conclusion:null});
 assert(prFastErrors(e).length);assert.deepEqual(prFastErrors(e,{allowRunningAggregate:true}),[]);
 Object.assign(e.jobs.find(j=>j.name==='fast (windows-2025)'),{status:'in_progress',conclusion:null});
 assert(prFastErrors(e,{allowRunningAggregate:true}).length);
});
test('Fast refuses missing, duplicate, unknown, Full, single-platform, failed and cancelled executions',()=>{
 for(const mutate of [
  e=>delete e.jobs,e=>e.jobs.pop(),e=>e.jobs=e.jobs.filter(j=>j.name!=='fast (windows-2025)'),
  e=>e.jobs.push({...e.jobs[0],id:900}),e=>e.jobs.push({...e.jobs[0],id:900,name:'rules (1/17)'}),
  e=>e.jobs[0].id=e.jobs[1].id,e=>e.jobs[0].run_id++,e=>e.jobs[0].head_sha=sha('d'),
  e=>e.jobs[0].run_attempt=2,e=>e.jobs[0].run_attempt=0,
  ...['failure','cancelled','timed_out','skipped',null].map(conclusion=>e=>e.jobs.find(j=>j.name==='fast (ubuntu-24.04)').conclusion=conclusion),
  e=>e.jobs.find(j=>j.name==='rules').conclusion='success',
  e=>e.jobs.find(j=>j.name==='engineering-posix-shards').status='queued',
 ]) {const e=fixture();mutate(e);assert(prFastErrors(e).length,String(mutate));}
});
test('latest failed execution wins over an older successful execution',()=>{
 const e=fixture(),first=e.jobs.find(j=>j.name==='fast (windows-2025)');
 e.attempt=e.run.run_attempt=e.latestRun.run_attempt=2;e.jobs.forEach(j=>j.run_attempt=2);
 e.jobs.push({...first,id:900,run_attempt:1,conclusion:'success'});first.conclusion='failure';
 assert(fastQualityJobErrors(e.jobs,{attempt:2,runId:7,head:e.head}).length);
 first.conclusion='success';assert.deepEqual(fastQualityJobErrors(e.jobs,{attempt:2,runId:7,head:e.head}),[]);
 first.run_attempt=1;assert(fastQualityJobErrors(e.jobs,{attempt:2,runId:7,head:e.head}).length);
});
test('Fast rejects stale run/attempt and changed PR/target/merge identity',()=>{
 for(const mutate of [
  e=>e.latestRun.id++,e=>e.latestRun.run_attempt++,e=>e.run.head_sha=sha('d'),e=>e.run.event='push',
  e=>e.run.repository.full_name='other/repo',e=>e.run.pull_requests=[],e=>e.run.path='other.yml',
  e=>e.run.conclusion='cancelled',e=>e.pr.number++,e=>e.pr.state='closed',e=>e.pr.merged=true,
  e=>e.pr.draft=true,e=>e.pr.head.sha=sha('d'),e=>e.pr.head.repo.full_name='other/repo',
  e=>e.pr.base.ref='master',e=>e.pr.base.sha=sha('d'),e=>e.target=sha('d'),
  e=>e.pr.merge_commit_sha=sha('d'),e=>e.commit.parents.reverse(),e=>e.commit.sha=sha('d'),
  e=>e.pr.labels=[{name:'ci:full'}],e=>delete e.pr.labels,e=>e.pr.labels=[null],e=>delete e.repo,
 ]) {const e=fixture();mutate(e);assert(prFastErrors(e).length,String(mutate));}
});
test('green metadata alone cannot certify a Fast PR or a borrowed checkout artifact',()=>{
 for(const mutate of [
  e=>delete e.checkout,e=>delete e.checkoutArtifact,e=>e.checkout.attempt++,e=>e.checkoutArtifact.id=0,
  e=>e.checkoutArtifact.name='quality-7-1-check',e=>e.checkoutArtifact.expired=true,
  e=>e.checkoutArtifact.workflow_run.id++,e=>e.checkoutArtifact.workflow_run.head_sha=sha('d'),
  ...['runId','prNumber'].map(key=>e=>e.checkout[key]++),
  ...['head','base','tested'].map(key=>e=>e.checkout[key]=sha('d')),
  e=>e.checkout.event='merge_group',e=>e.checkout.parents.reverse(),e=>e.receiptError='download failed',
 ]) {const e=fixture();mutate(e);assert(prFastErrors(e).length,String(mutate));}
 const e=fixture();delete e.checkout;delete e.checkoutArtifact;delete e.plan;
 assert.deepEqual(prFastErrors(e,{metadataOnly:true}),[]);
});
test('Fast plan binds exact head/base/attempt and complete unique canonical test paths',()=>{
 for(const mutate of [
  e=>delete e.plan,e=>e.plan.mode='full',e=>e.plan.sha=sha('d'),e=>e.plan.head=sha('d'),
  e=>e.plan.base=sha('d'),e=>e.plan.runId++,e=>e.plan.attempt++,e=>e.plan.changed=[],
  e=>e.plan.changed.push(e.plan.changed[0]),e=>e.plan.changed=['../outside.mjs'],
  e=>e.plan.js.push(e.plan.js[0]),e=>e.plan.js=['tests/helpers/value.mjs'],
  e=>e.plan.js=['tests/../value.test.mjs'],e=>e.plan.lua=['tests\\lua\\value.lua'],
  e=>e.plan.reason='',e=>e.plan.js=[],
 ]) {const e=fixture();mutate(e);assert(prFastErrors(e).length,String(mutate));}
});
test('explicit prose-only Fast may have zero tests; unknown prose cannot borrow that exception',()=>{
 const e=fixture();e.plan.js=[];e.plan.changed=['docs/CI.md','docs/HANDOFF.md','docs/CI-FAST.md'];
 assert.deepEqual(prFastErrors(e),[]);
 for(const path of ['docs/design/UI_DESIGN.md','docs/evidence/test.json','README.md','unknown']) {
  e.plan.changed=['docs/CI.md',path];assert(prFastErrors(e).length,path);
 }
});
function downloadedProof(e,mutate=()=>{}) {
 const dir=mkdtempSync(join(tmpdir(),'fast-proof-')),calls=[];
 const query=(...args)=>{
  calls.push(args);
  if(args[0]==='run') {
   writeFileSync(join(dir,'ci-checkout.json'),JSON.stringify(e.checkout));
   writeFileSync(join(dir,'ci-impact.json'),JSON.stringify(e.plan));return '';
  }
  if(args.at(-1).includes('/artifacts?'))return JSON.stringify([{artifacts:[e.checkoutArtifact]}]);
  const current=structuredClone(e.checkoutArtifact);mutate(current);return JSON.stringify(current);
 };
 try{return {proof:collectFastCheckout(repo,e.run,e.jobs,dir,query),calls};}
 finally{rmSync(dir,{recursive:true,force:true});}
}
test('collector downloads both receipt and plan and reads back immutable artifact ID',()=>{
 const e=fixture(),{proof,calls}=downloadedProof(e);
 assert.deepEqual(proof,{checkout:e.checkout,plan:e.plan,checkoutArtifact:e.checkoutArtifact});
 assert.equal(calls.length,3);assert(calls[1].includes('quality-7-1-fast'));
 assert.equal(calls[2].at(-1),'repos/'+repo+'/actions/artifacts/300');
});
test('collector rejects expired/replaced artifact after download and invalid inventory before download',()=>{
 for(const mutate of [a=>a.id++,a=>a.expired=true,a=>a.workflow_run.head_sha=sha('d'),a=>a.name='other'])
  assert.throws(()=>downloadedProof(fixture(),mutate),/changed during download/);
 for(const response of [[],[{}],[{artifacts:[]}],[{artifacts:[fixture().checkoutArtifact,fixture().checkoutArtifact]}]]) {
  let download=false;
  assert.throws(()=>collectFastCheckout(repo,fixture().run,fixture().jobs,'.',(...args)=>{
   if(args[0]==='run')download=true;return JSON.stringify(response);
  }),/inventory|artifact/);assert.equal(download,false);
 }
 const e=fixture();e.jobs.pop();let calls=0;
 assert.throws(()=>collectFastCheckout(repo,e.run,e.jobs,'.',()=>{calls++;return ''; }));assert.equal(calls,0);
});

// One API model exercises the actual publishers, download collectors, native
// authorization handshake and post-merge verifier without replacing any of
// their validation functions with a test double.
function lifecycle({full=false,legacy=false}={}) {
 const e=fixture(),dir=mkdtempSync(join(tmpdir(),'fast-lifecycle-')),calls=[],writes=[];
 const identity={id:projectRepositoryId,full_name:repo};
 Object.assign(e.pr,{node_id:'PR_fast_531',mergeable:true,changed_files:1,body:'Depends-on: none',auto_merge:null});
 Object.assign(e.pr.head,{ref:'feat/safe-fast',repo:identity});e.pr.base.repo=identity;
 e.commit.commit={tree:{sha:sha('f')}};e.run.head_branch=e.pr.head.ref;
 const review={reviewId:'independent-fast-lifecycle',reviewedHeadSha:e.head,reviewedBaseSha:e.base,conclusion:'pass',unresolved:[],repo,prNumber:e.number};
 const settings={...identity,allow_auto_merge:true,allow_squash_merge:true};
 const ruleset={id:25870651,updated_at:'2026-11-06T12:00:00Z',target:'branch',enforcement:'active',bypass_actors:[],
  conditions:{ref_name:{include:['refs/heads/develop'],exclude:[]}},rules:[
   {type:'pull_request',parameters:{allowed_merge_methods:['squash'],required_review_thread_resolution:true}},
   {type:'required_linear_history'},
   {type:'merge_queue',parameters:{merge_method:'SQUASH',grouping_strategy:'ALLGREEN'}},
   {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,
    required_status_checks:requiredContexts.map(context=>({context:!legacy&&context==='full-quality'?'pr-quality':context,
     integration_id:context===reviewContext?null:15368}))}},
  ]};
 if(full){
  e.jobs=currentFullQualityJobs.map((name,i)=>({id:100+i,name,run_id:7,run_attempt:1,head_sha:e.head,status:'completed',conclusion:name==='fast'?'skipped':'success'}));
  e.checkoutArtifact.name='quality-7-1-check';
 }
 const fullRun=(id,event,branch)=>({id,run_attempt:1,event,head_sha:sha('e'),head_branch:branch,
  path:'.github/workflows/quality.yml',repository:identity,status:'completed',conclusion:'success'});
 const groupRun=fullRun(8,'merge_group',`gh-readonly-queue/develop/pr-${e.number}-${e.base}`),pushRun=fullRun(9,'push','develop');
 const fullJobs=run=>currentFullQualityJobs.map((name,i)=>({id:run.id*100+i,name,run_id:run.id,run_attempt:1,head_sha:run.head_sha,status:'completed',conclusion:name==='fast'?'skipped':'success'}));
 const receipt=run=>({checkout:{schemaVersion:1,event:run.event,runId:run.id,attempt:1,head:run.head_sha,tested:run.head_sha,base:e.base,parents:[e.base]},
  checkoutArtifact:{id:run.id*1000,name:`quality-${run.id}-1-check`,expired:false,workflow_run:{id:run.id,head_sha:run.head_sha}}});
 const licenseRun={...groupRun,id:10,path:'.github/workflows/licenses.yml'},licenseJobs=[{
  id:1001,name:'inventory',run_id:10,run_attempt:1,head_sha:sha('e'),status:'completed',conclusion:'success'}];
 const state={e,dir,calls,writes,review,ruleset,groupRun,pushRun,groupJobs:fullJobs(groupRun),pushJobs:fullJobs(pushRun),
  licenseRun,licenseJobs,merged:false,armed:false,statuses:[],afterDownload:undefined,licenseListings:0,newLicenseFailure:false};
 let statusId=500;
 const query=(...args)=>{
  calls.push(args);
  if(args[0]==='run'){
   const runId=Number(args[2]),target=args[args.indexOf('--dir')+1];
   const proof=runId===7?{checkout:e.checkout,plan:e.plan}:receipt(runId===8?groupRun:pushRun);
   writeFileSync(join(target,'ci-checkout.json'),JSON.stringify(proof.checkout));
   if(proof.plan)writeFileSync(join(target,'ci-impact.json'),JSON.stringify(proof.plan));
   state.afterDownload?.(runId);return '';
  }
  if(args[0]==='pr'){assert(args.includes('--disable-auto'));state.armed=false;return '';}
  if(args[1]==='graphql'){
   const text=args.find(a=>a.startsWith('query='));
   if(text.includes('enablePullRequestAutoMerge')){
    assert.equal(state.statuses.filter(s=>s.context===reviewContext).at(-1)?.state,'pending');
    assert(args.includes('head='+e.head),'native activation binds the reviewed HEAD');state.armed=true;return '{}';
   }
   assert(text.includes('... on PullRequest'),'unexpected native mutation');
   const queued=state.armed&&state.statuses.filter(s=>s.context===reviewContext).at(-1)?.state==='success';
   return JSON.stringify({data:{node:{id:e.pr.node_id,number:e.number,state:'OPEN',baseRefName:'develop',headRefOid:e.head,
    repository:{databaseId:projectRepositoryId,nameWithOwner:repo},isInMergeQueue:queued,isMergeQueueEnabled:true,
    autoMergeRequest:state.armed?{mergeMethod:'SQUASH'}:null,mergeQueue:{id:'MQ_develop',configuration:{mergeMethod:'SQUASH',mergingStrategy:'ALLGREEN'}},
    mergeQueueEntry:queued?{id:'MQE_fast',state:'AWAITING_CHECKS',mergeQueue:{id:'MQ_develop'},
     pullRequest:{id:e.pr.node_id,number:e.number,headRefOid:e.head,baseRefName:'develop'}}:null}}});
  }
  const endpoint=args.includes('--method')?args.find(a=>a.startsWith('repos/')):args.at(-1);
  if(args.includes('POST')){
   const status={id:++statusId,state:args.find(a=>a.startsWith('state=')).slice(6),context:args.find(a=>a.startsWith('context=')).slice(8),
    description:args.find(a=>a.startsWith('description='))?.slice(12)};
   writes.push(status);state.statuses.push(status);return JSON.stringify(status);
  }
  if(endpoint===`repos/${repo}`||endpoint==='repositories/'+projectRepositoryId)return JSON.stringify(settings);
  if(endpoint.endsWith('/rulesets/25870651'))return JSON.stringify(ruleset);
  if(endpoint.endsWith('/pulls/'+e.number))return JSON.stringify({...e.pr,
   ...(state.merged?{state:'closed',merged:true,merge_commit_sha:sha('e')}:{auto_merge:state.armed?{merge_method:'squash'}:null})});
  if(endpoint.endsWith('/git/ref/heads/develop'))return JSON.stringify({ref:'refs/heads/develop',object:{type:'commit',sha:e.target}});
  if(endpoint.endsWith('/commits/'+e.tested))return JSON.stringify(e.commit);
  if(endpoint.endsWith('/commits/'+sha('e')))return JSON.stringify({sha:sha('e'),parents:[{sha:e.base}],commit:{tree:{sha:sha('f')}}});
  if(endpoint.includes('/statuses?')){
   if(endpoint.includes('/commits/'+e.head+'/'))return JSON.stringify([state.statuses]);
   return JSON.stringify([['full-quality','pr-quality','independent-review'].map((context,i)=>({id:900+i,context,state:'success',
    creator:{id:41898282,login:'github-actions[bot]'},target_url:`https://github.com/${repo}/actions/runs/8`}))]);
  }
  if(endpoint.includes('/actions/workflows/licenses.yml/')){
   state.licenseListings++;
   const runs=[licenseRun];
   if(state.newLicenseFailure&&state.licenseListings>1)runs.push({...licenseRun,id:11,status:'completed',conclusion:'failure'});
   return JSON.stringify([{workflow_runs:runs}]);
  }
  if(endpoint.includes('/actions/workflows/quality.yml/'))return JSON.stringify([{workflow_runs:[
   endpoint.includes('event=merge_group')?groupRun:endpoint.includes('event=push')?pushRun:e.run]}]);
  const jobsMatch=endpoint.match(/\/actions\/runs\/(\d+)\/jobs\?/);
  if(jobsMatch)return JSON.stringify([{jobs:({7:e.jobs,8:state.groupJobs,9:state.pushJobs,10:licenseJobs})[jobsMatch[1]]}]);
  const runMatch=endpoint.match(/\/actions\/runs\/(\d+)$/);
  if(runMatch)return JSON.stringify(({7:e.run,8:groupRun,9:pushRun,10:licenseRun})[runMatch[1]]);
  const artifactsMatch=endpoint.match(/\/actions\/runs\/(\d+)\/artifacts\?/);
  if(artifactsMatch)return JSON.stringify([{artifacts:[Number(artifactsMatch[1])===7?e.checkoutArtifact:receipt(Number(artifactsMatch[1])===8?groupRun:pushRun).checkoutArtifact]}]);
  const artifactMatch=endpoint.match(/\/actions\/artifacts\/(\d+)$/);
  if(artifactMatch)return JSON.stringify(Number(artifactMatch[1])===300?e.checkoutArtifact:receipt(Number(artifactMatch[1])===8000?groupRun:pushRun).checkoutArtifact);
  throw Error('Unexpected lifecycle query '+JSON.stringify(args));
 };
 state.query=query;
 state.load=(run,jobs)=>{
  const subdir=mkdtempSync(join(dir,'download-'));
  return run.id===7&&!full?collectFastCheckout(repo,run,jobs,subdir,query,{allowRunningAggregate:run.status==='in_progress'}):
   checkoutReceipt(repo,run,jobs,subdir,query,3,{allowRunningAggregate:run.status==='in_progress'});
 };
 state.publish=()=>{
  const eventFile=join(dir,'event.json');writeFileSync(eventFile,JSON.stringify({pull_request:e.pr}));
  return publishPrQuality({GITHUB_EVENT_PATH:eventFile,GITHUB_EVENT_NAME:'pull_request',GITHUB_REPOSITORY:repo,
   GITHUB_SHA:e.tested,GITHUB_RUN_ID:'7',GITHUB_RUN_ATTEMPT:'1',FULL_MODE:full?'full':'fast',FULL_NEEDS:JSON.stringify({
    impact:{result:'success'},rules:{result:full?'success':'skipped'},fast:{result:full?'skipped':'success'},
    presentation:{result:'success'},'engineering-posix':{result:'success'}})},query,{loadCheckout:state.load});
 };
 state.running=()=>{e.run.status='in_progress';e.run.conclusion=null;Object.assign(e.jobs.find(j=>j.name==='check'),{status:'in_progress',conclusion:null});};
 state.complete=()=>{e.run.status='completed';e.run.conclusion='success';Object.assign(e.jobs.find(j=>j.name==='check'),{status:'completed',conclusion:'success'});};
 state.cleanup=()=>{assert(dir.startsWith(join(tmpdir(),'fast-lifecycle-')));rmSync(dir,{recursive:true,force:true});};
 return state;
}
function authorizeFast(state){
 state.complete();
 const collected=collectPrDelivery(repo,state.e.number,state.review,state.query,state.load);
 assert.equal(collected.evidence.schemaVersion,7);assert.deepEqual(verifyDelivery(collected.evidence),[]);
 const result=armAutoMerge(repo,state.e.number,state.review,state.query,{loadCheckout:state.load});
 assert.equal(result.proof.schemaVersion,6);assert.deepEqual(verifyAutoMergeArm(result.proof),[]);return result.proof;
}
function mergedResult(state,proof){
 try{return verifyMergedDelivery(collectMergedDelivery(repo,state.e.number,proof,state.query,state.load));}
 catch(error){return {state:'merged_pending',errors:[error.message]};}
}
test('actual Fast publisher, immutable collector, native handshake and queue/push Full produce merged_passed',()=>{
 const m=lifecycle();
 try{
  m.running();assert.equal(m.publish().state,'success');
  assert(m.writes.some(s=>s.context==='pr-quality'&&s.state==='success'));
  assert(!m.writes.some(s=>s.context==='full-quality'&&s.state==='success'),'Fast must never publish Full success');
  const proof=authorizeFast(m);assert(m.armed);
  assert(m.writes.some(s=>s.context===reviewContext&&s.state==='pending'));
  assert(m.writes.some(s=>s.context===reviewContext&&s.state==='success'));
  m.merged=true;assert.deepEqual(mergedResult(m,proof),{state:'merged_passed',errors:[]});
  const evidence=collectMergedDelivery(repo,m.e.number,proof,m.query,m.load);
  delete evidence.queueFull;assert.equal(verifyMergedDelivery(evidence).state,'merged_pending');
 }finally{m.cleanup();}
});

test('direct schema7 Fast delivery also requires the actual queue Full before merged_passed',()=>{
 const m=lifecycle();
 try{
  m.complete();const {evidence}=collectPrDelivery(repo,m.e.number,m.review,m.query,m.load);
  assert.equal(evidence.schemaVersion,7);m.merged=true;
  const collected=collectMergedDelivery(repo,m.e.number,evidence,m.query,m.load);
  assert.equal(collected.queueFull.schemaVersion,8);
  assert.equal(verifyMergedDelivery(collected).state,'merged_passed');
  delete collected.queueFull;
  assert.equal(verifyMergedDelivery(collected).state,'merged_pending');
 }finally{m.cleanup();}
});
test('download-time cancellation, rerun, HEAD/BASE, Full request and draft changes never publish Fast success',()=>{
 for(const [name,change]of [
  ['cancel same attempt',m=>{m.e.run.status='completed';m.e.run.conclusion='cancelled';}],
  ['new attempt',m=>m.e.run.run_attempt++],['new head',m=>m.e.pr.head.sha=sha('d')],
  ['new base',m=>m.e.target=sha('d')],['request Full',m=>m.e.pr.labels.push({name:'ci:full'})],
  ['draft',m=>m.e.pr.draft=true],
 ]){
  const m=lifecycle();try{
   m.running();m.afterDownload=()=>change(m);
   try{m.publish();}catch(error){assert(error instanceof Error);}
   assert(!m.writes.some(s=>s.state==='success'),name);
  }finally{m.cleanup();}
 }
});
test('Full path likewise cannot overwrite cancellation with a PR quality success',()=>{
 const m=lifecycle({full:true});try{
  m.running();m.afterDownload=()=>{m.e.run.status='completed';m.e.run.conclusion='cancelled';};
  try{m.publish();}catch(error){assert(error instanceof Error);}
  assert(!m.writes.some(s=>s.state==='success'));
 }finally{m.cleanup();}
});
test('collector rechecks Fast policy changed during the immutable download',()=>{
 for(const change of [m=>m.e.pr.draft=true,m=>m.e.pr.labels.push({name:'ci:full'})]){
  const m=lifecycle();try{
   m.afterDownload=()=>change(m);
   const {evidence}=collectPrDelivery(repo,m.e.number,m.review,m.query,m.load);
   assert(verifyDelivery(evidence).length);
   assert.throws(()=>armAutoMerge(repo,m.e.number,m.review,m.query,{loadCheckout:m.load}));
   assert(!m.calls.some(args=>args.some(arg=>typeof arg==='string'&&arg.includes('enablePullRequestAutoMerge'))));
  }finally{m.cleanup();}
 }
});
test('Fast activation rejects missing native queue, wrong required source and non-Strict protection',()=>{
 for(const change of [
  m=>m.ruleset.rules=m.ruleset.rules.filter(r=>r.type!=='merge_queue'),
  m=>m.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks.find(c=>c.context==='pr-quality').integration_id=null,
  m=>m.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.strict_required_status_checks_policy=false,
 ]){
  const m=lifecycle();try{
   change(m);assert.throws(()=>armAutoMerge(repo,m.e.number,m.review,m.query,{loadCheckout:m.load}));
   assert(!m.writes.length);
  }finally{m.cleanup();}
 }
});
test('failed, cancelled, missing platform and stale Fast SHA cannot arm native merging',()=>{
 for(const change of [
  m=>m.e.jobs.find(j=>j.name==='fast (windows-2025)').conclusion='failure',
  m=>m.e.jobs.find(j=>j.name==='fast (ubuntu-24.04)').conclusion='cancelled',
  m=>m.e.jobs=m.e.jobs.filter(j=>j.name!=='fast (ubuntu-24.04)'),
  m=>m.e.checkout.tested=sha('d'),m=>m.e.plan.head=sha('d'),
 ]){
  const m=lifecycle();try{
   change(m);assert.throws(()=>armAutoMerge(repo,m.e.number,m.review,m.query,{loadCheckout:m.load}));
   assert(!m.writes.length);
  }finally{m.cleanup();}
 }
});
test('Fast authorization never substitutes for queue Full, inventory or normal develop push Full',()=>{
 for(const change of [
  m=>m.groupJobs=m.e.jobs.map(j=>({...j,run_id:8,head_sha:sha('e')})),
  m=>m.groupJobs.pop(),m=>m.groupRun.conclusion='cancelled',
  m=>m.groupJobs.find(j=>j.name.startsWith('rules (')).conclusion='failure',
  m=>m.licenseJobs[0].conclusion='failure',m=>m.newLicenseFailure=true,
  m=>m.pushJobs.find(j=>j.name.startsWith('rules (')).conclusion='failure',
 ]){
  const m=lifecycle();try{
   const proof=authorizeFast(m);m.merged=true;change(m);
   const result=mergedResult(m,proof);assert.equal(result.state,'merged_pending');assert(result.errors.length);
  }finally{m.cleanup();}
 }
});
test('old Full-required bootstrap still uses the complete Full evidence and schema4 handshake',()=>{
 const m=lifecycle({full:true,legacy:true});try{
  const result=armAutoMerge(repo,m.e.number,m.review,m.query,{loadCheckout:m.load});
  assert.equal(result.proof.schemaVersion,4);assert.equal(result.proof.fullPreflight.schemaVersion,3);
  assert.deepEqual(verifyAutoMergeArm(result.proof),[]);
 }finally{m.cleanup();}
});
