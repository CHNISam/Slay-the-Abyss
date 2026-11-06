import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {currentFastQualityJobs,fastQualityJobErrors,prFastErrors,collectFastCheckout} from '../scripts/pr-quality-evidence.mjs';

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
