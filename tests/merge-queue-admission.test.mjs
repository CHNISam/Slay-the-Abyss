import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {main} from '../scripts/publish-merge-group.mjs';

import {admissionFixture,admissionQuery} from './helpers/merge-queue-admission.mjs';
import {queueRulesFingerprint} from '../scripts/merge-queue-policy.mjs';
const sha=c=>c.repeat(40);
function execute(f,query=admissionQuery(f),options){
 const dir=mkdtempSync(join(tmpdir(),'queue-admission-'));
 try{f.env.GITHUB_EVENT_PATH=join(dir,'event.json');writeFileSync(f.env.GITHUB_EVENT_PATH,JSON.stringify(f.event));
  return main(f.env,query,options);
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('real checkout loader accepts only the effective receipt execution attempt',()=>{
 const valid=admissionFixture();assert.equal(execute(valid).state,'success');
 for(const attempt of [undefined,0,99]){
  const f=admissionFixture(),writes=[];f.checkout.attempt=attempt;
  assert.throws(()=>execute(f,admissionQuery(f,writes)),/receipt|artifact|attempt/i);
  assert.deepEqual(writes,[]);
 }
});

test('read-only ruleset visibility can release only a matching privileged authorization',()=>{
 const f=admissionFixture();
 delete f.ruleset.bypass_actors;
 assert.equal(execute(f).state,'success');
});

test('hidden bypass configuration requires immutable policy version and exact current coordinator',()=>{
 for(const mutate of [
  f=>f.review.description=`Independent review [base:${f.event.merge_group.base_sha}]`,
  f=>f.review.description=f.review.description.replace(/rules:[0-9a-f]{64}/,'rules:'+ '0'.repeat(64)),
  f=>delete f.ruleset.updated_at,f=>f.ruleset.updated_at='not-a-date',
  f=>f.ruleset.updated_at='2026-11-04T17:51:24.025+08:00',
  f=>f.ruleset.id=7,f=>f.ruleset.rules[0].parameters.check_response_timeout_minutes=121,
  f=>f.ruleset.bypass_actors=null,f=>f.ruleset.bypass_actors=[{actor_id:51}],
  f=>delete f.review.creator,f=>f.review.creator.id=52,f=>f.review.creator.login='other',
  f=>delete f.entry.enqueuer,f=>f.entry.enqueuer.databaseId=52,f=>f.entry.enqueuer.login='other',
  f=>delete f.permission.permission,f=>f.permission.permission='write',f=>f.permission.permission='maintain',
  f=>delete f.permission.user,f=>f.permission.user.id=52,f=>f.permission.user.login='other'
 ]){
  for(const duringDownload of [false,true]){
   const f=admissionFixture(),writes=[];
   delete f.ruleset.bypass_actors;
   const receipt={checkout:structuredClone(f.checkout),checkoutArtifact:structuredClone(f.artifact)};
   if(!duringDownload)mutate(f);
   assert.throws(()=>execute(f,admissionQuery(f,writes),{loadCheckout:()=>{
    if(duringDownload)mutate(f);return receipt;
   }}),undefined,String(mutate));
   assert.deepEqual(writes,[],String(mutate));
  }
 }
});

test('policy digest is stable across JSON key order but never authorizes invisible bypass at coordinator',()=>{
 const f=admissionFixture(),full=f.ruleset;
 const reversed=Object.fromEntries(Object.entries(full).reverse());
 assert.equal(queueRulesFingerprint(full),queueRulesFingerprint(reversed));
 assert.equal(queueRulesFingerprint(full),queueRulesFingerprint({...full,updated_at:'2026-11-04T09:51:23.025Z'}),
  'real public and privileged API timezone renderings identify the same policy instant');
 const redacted=structuredClone(full);delete redacted.bypass_actors;
 assert.throws(()=>queueRulesFingerprint(redacted),/explicitly empty bypass/);
 assert.equal(queueRulesFingerprint(redacted,{allowRedacted:true}),queueRulesFingerprint(full));
 for(const bypass_actors of [undefined,null,[{}],{}])
  assert.throws(()=>queueRulesFingerprint({...full,bypass_actors},{allowRedacted:true}),/bypass/);
 for(const updated_at of [null,'','1','2026-11-04','2026-11-04T09:51:23','not-a-date'])
  assert.throws(()=>queueRulesFingerprint({...full,updated_at}),/versioned/);
});

test('missing administrator metadata capability cannot publish queue gates',()=>{
 const f=admissionFixture(),writes=[],query=admissionQuery(f,writes);
 assert.throws(()=>execute(f,(...args)=>{
  if(args.some(arg=>arg.includes('/collaborators/')))throw Error('HTTP 403 metadata unavailable');
  return query(...args);
 }),/403/);
 assert.deepEqual(writes,[]);
});
test('queue release rejects paused, held, changed dependency and stale-base PR authorization',()=>{
 for(const mutate of [
  f=>f.review.state='failure',f=>f.review.description='Independent review without BASE',
  f=>f.review.description=`Independent review [base:${sha('d')}]`,
  f=>f.pr.labels=[{name:'hold'}],f=>f.pr.body='Depends-on: #999',
  f=>f.pr.body='Depends-on: none\nDepends-on: #999',
  f=>f.pr.draft=true,f=>f.pr.head.sha=sha('d'),f=>f.pr.base.sha=sha('d'),
  f=>f.repository.ref.target.oid=sha('d'),f=>f.repository.databaseId=7,
  f=>f.repository.mergeQueue.entries.nodes=[],
  f=>f.repository.mergeQueue.entries.pageInfo.hasNextPage=true,
  f=>f.entry.headCommit.oid=sha('d'),f=>f.entry.pullRequest.mergeQueueEntry=null
 ]){
  const f=admissionFixture(),writes=[];mutate(f);
  assert.throws(()=>execute(f,admissionQuery(f,writes)),undefined,String(mutate));
  assert.deepEqual(writes,[],String(mutate));
 }
});
test('queue release rechecks protection and PR admission after downloading immutable evidence',()=>{
 for(const mutate of [f=>f.ruleset.bypass_actors=[{actor_id:9}],
  f=>f.review.state='failure',f=>f.pr.labels=[{name:'hold'}],
  f=>f.repository.mergeQueue.entries.nodes=[]]){
  const f=admissionFixture(),writes=[];
  assert.throws(()=>execute(f,admissionQuery(f,writes),{loadCheckout:()=>{
   const result={checkout:structuredClone(f.checkout),checkoutArtifact:structuredClone(f.artifact)};
   mutate(f);return result;
  }}));
  assert.deepEqual(writes,[]);
 }
});
test('queue release refuses policy combinations that differ from staged rollout',()=>{
 for(const parameters of [{merge_method:'MERGE',grouping_strategy:'ALLGREEN'},
  {merge_method:'SQUASH',grouping_strategy:'HEADGREEN'},undefined]){
  const f=admissionFixture(),writes=[];f.ruleset.rules[0].parameters=parameters;
  assert.throws(()=>execute(f,admissionQuery(f,writes)),/Queue|queue/);
  assert.deepEqual(writes,[]);
 }
});
test('queue release preserves Strict, squash-only PRs, resolved threads and linear history',()=>{
 for(const mutate of [f=>f.ruleset.rules[1].parameters.strict_required_status_checks_policy=false,
  f=>f.ruleset.rules=f.ruleset.rules.filter(r=>r.type!=='pull_request'),
  f=>f.ruleset.rules=f.ruleset.rules.filter(r=>r.type!=='required_linear_history'),
  f=>f.ruleset.rules[2].parameters.allowed_merge_methods.push('merge'),
  f=>f.ruleset.rules[2].parameters.required_review_thread_resolution=false]){
  for(const duringDownload of [false,true]){
   const f=admissionFixture(),writes=[],receipt={checkout:structuredClone(f.checkout),checkoutArtifact:structuredClone(f.artifact)};
   if(!duringDownload)mutate(f);
   assert.throws(()=>execute(f,admissionQuery(f,writes),{loadCheckout:()=>{
    if(duringDownload)mutate(f);return receipt;
   }}),undefined,String(mutate));
   assert.deepEqual(writes,[]);
  }
 }
});
test('downloaded receipt parents must equal the actual queue commit parent vector',()=>{
 for(const parents of [[],[sha('d')],[sha('b'),sha('d')]]){
  const f=admissionFixture(),writes=[];f.checkout.parents=parents;
  assert.throws(()=>execute(f,admissionQuery(f,writes)),/parent/i);
  assert.deepEqual(writes,[]);
 }
});

test('Fast queue admission rechecks the latest PR run/attempt before and after receipt download',()=>{
 for(const mutate of [()=>{},f=>f.qualityStatus.state='pending',f=>f.prRun.conclusion='cancelled',
  f=>f.prRun.status='in_progress',f=>f.prRun.run_attempt++,f=>f.prRun.id++,
  f=>f.qualityStatus.creator.id=1,f=>f.qualityStatus.target_url='https://github.com/old',
  f=>f.qualityStatus.description='Exact dual-platform Fast run 9, attempt 0']){
  for(const duringDownload of [false,true]){
   const f=admissionFixture(),writes=[];
   f.ruleset.rules[1].parameters.required_status_checks.find(c=>c.context==='full-quality').context='pr-quality';
   f.review.description=`Independent review [rules:${queueRulesFingerprint(f.ruleset)}] [base:${f.pr.base.sha}]`;
   f.prRun={id:9,run_attempt:1,head_sha:f.pr.head.sha,event:'pull_request',path:'.github/workflows/quality.yml',
    status:'completed',conclusion:'success',repository:{full_name:'FurinyaWorks/Slay-the-Abyss'},pull_requests:[{number:510}]};
   f.qualityStatus={id:91,context:'pr-quality',state:'success',creator:{id:41898282,login:'github-actions[bot]'},
    target_url:'https://github.com/FurinyaWorks/Slay-the-Abyss/actions/runs/9',description:'Exact dual-platform Fast run 9, attempt 1'};
   const underlying=admissionQuery(f,writes),query=(...args)=>{
    const endpoint=args.at(-1);
    if(endpoint.includes('/statuses?'))return JSON.stringify([[f.review,f.qualityStatus]]);
    if(endpoint.includes('/actions/workflows/')&&endpoint.includes('event=pull_request'))return JSON.stringify([{workflow_runs:[f.prRun]}]);
    return underlying(...args);
   };
   const receipt={checkout:structuredClone(f.checkout),checkoutArtifact:structuredClone(f.artifact)};
   if(!duringDownload)mutate(f);
   const run=()=>execute(f,query,{loadCheckout:()=>{if(duringDownload)mutate(f);return receipt;}});
   if(mutate.toString()==='()=>{}')assert.equal(run().state,'success');
   else{assert.throws(run,/admission|changed/);assert.deepEqual(writes,[]);}
  }
 }
});
