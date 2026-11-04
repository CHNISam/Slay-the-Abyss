import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {parseDependencies,autoMergeErrors,collectEligibility,armAutoMerge as activate,pauseAutoMerge,reviewContext,requiredContexts,main,repositoryFullName,repositoryId} from '../scripts/arm-auto-merge.mjs';
import {verifyAutoMergeArm,verifyDelivery,verifyHistoricalAutoFull,verifyMergedDelivery,collectMergedDelivery,currentFullQualityJobs,qualityWorkflowPath} from '../scripts/verify-delivery.mjs';

const sha=c=>c.repeat(40);
const armAutoMerge=(repo,number,review,query,options={})=>activate(repo,number,review,query,{loadCheckout:query.loadCheckout,...options});
const repo='FurinyaWorks/Slay-the-Abyss';
function fixture() {
  const pr={number:510,node_id:'PR_reviewed_510',state:'open',merged:false,draft:false,mergeable:true,changed_files:1,
    head:{sha:sha('a'),ref:'feat/reviewed',repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},merge_commit_sha:sha('d'),body:'Summary\n\nDepends-on: none',
    labels:[]};
  const review={reviewId:'independent-agent-evidence-100',reviewedHeadSha:sha('a'),
    reviewedBaseSha:sha('b'),conclusion:'pass',unresolved:[],repo,prNumber:510};
  const settings={id:1429751262,full_name:repo,allow_auto_merge:true,allow_squash_merge:true};
  const ruleset={target:'branch',enforcement:'active',conditions:{ref_name:{include:['refs/heads/develop'],exclude:[]}},
    rules:[
      {type:'pull_request',parameters:{allowed_merge_methods:['squash'],required_review_thread_resolution:true}},
      {type:'required_linear_history'},
      {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,
        required_status_checks:requiredContexts.map(context=>({context,integration_id:context===reviewContext?null:15368}))}}
    ]};
  return {pr,review,settings,ruleset,repo,baseSha:sha('b'),dependencies:[]};
}
function mock(opts={}) {
  const f=fixture(),calls=[];let pulls=0,armed=false,statusId=10;
  let reviewStatus={id:statusId,context:reviewContext,state:'success'};
  const run={id:7,run_attempt:1,event:'pull_request',head_sha:sha('a'),path:qualityWorkflowPath,
    repository:{full_name:repo},status:'completed',conclusion:'success',pull_requests:[{number:510}]};
  const jobs=currentFullQualityJobs.map((name,i)=>({id:100+i,name,status:'completed',
    conclusion:name==='fast'?'skipped':'success',run_attempt:1,run_id:7,head_sha:sha('a')}));
  if(opts.fastOnly)jobs.find(j=>j.name.startsWith('rules')).conclusion='skipped';
  if(opts.pending){run.status='in_progress';run.conclusion=null;for(const job of jobs)if(job.name!=='fast'){job.status='queued';job.conclusion=null;}}
  if(opts.pendingFailure)jobs.find(j=>j.name.startsWith('rules')).conclusion='failure';
  const checkout={schemaVersion:1,attempt:1,event:'pull_request',runId:7,prNumber:510,
    head:sha('a'),base:sha('b'),tested:sha('d'),parents:[sha('b'),sha('a')]};
  const checkoutArtifact={id:200,name:'quality-7-1-check',expired:false,workflow_run:{id:7,head_sha:sha('a')}};
  const query=(...args)=>{
    calls.push(args);
    if(args[0]==='api'&&args[1]==='graphql'){
      assert(args.some(arg=>arg.includes('enablePullRequestAutoMerge')));
      assert(!args.some(arg=>arg.includes('mergePullRequest(input')));
      assert.equal(reviewStatus.state,'pending','native enable must be held behind the review gate');
      if(opts.activationFails)throw Error('activation failed');armed=true;return '{}';
    }
    if(args[0]==='pr') {
      if(args[1]==='merge'&&args.includes('--disable-auto')){armed=false;return '';}
      throw Error('Unexpected gh pr invocation');
    }
    const last=args.includes('--method')?args.find(x=>x.startsWith('repos/')):args.at(-1);
    if(args.includes('POST')){
      reviewStatus={id:++statusId,context:reviewContext,state:args.find(a=>a.startsWith('state=')).slice(6)};
      return JSON.stringify(reviewStatus);
    }
    if(last===`repos/${repo}/commits/${sha('a')}/statuses?per_page=100`)
      return JSON.stringify([[opts.overwrittenGate&&armed?{...reviewStatus,id:reviewStatus.id+1,state:'success'}:reviewStatus]]);
    if(last==='repos/'+repo+'/pulls/510') {
      ++pulls;
      const pr=structuredClone(f.pr);
      pr.auto_merge=null;pr.mergeable_state=reviewStatus.state==='pending'||opts.pending?'blocked':'clean';
      if(opts.missingAutoField)delete pr.auto_merge;
      if(opts.nextHead&&pulls>=2)pr.head.sha=opts.nextHead;
      if(opts.nextBase&&pulls>=2)pr.base.sha=opts.nextBase;
      if(armed&&(opts.mergeBeforeRelease||opts.mergeImmediately&&reviewStatus.state==='success')){pr.merged=true;pr.state='closed';pr.merge_commit_sha=sha('e');}
      if(armed&&!opts.missingAutoMerge)pr.auto_merge={merge_method:opts.mergeMethod??'squash'};
      if(pulls===7&&opts.finalTarget)pr.base.ref=opts.finalTarget;
      if(pulls===7&&opts.finalNumber)pr.number=opts.finalNumber;
      if(pulls===7&&opts.finalFork)pr.head.repo.full_name='other/repository';
      if(pulls===7&&opts.finalMergeCommit)pr.merge_commit_sha=sha('e');
      if(armed&&opts.finalHold){pr.labels=['hold'];pr.base.sha=sha('e');}
      return JSON.stringify(pr);
    }
    if(last==='repos/'+repo)return JSON.stringify(f.settings);
    if(last==='repos/'+repo+'/rulesets/25870651')return JSON.stringify(f.ruleset);
    if(last==='repos/'+repo+'/git/ref/heads/develop')
      return JSON.stringify({ref:'refs/heads/develop',object:{type:'commit',sha:opts.nextTarget&&pulls>=2?opts.nextTarget:f.baseSha}});
    if(last.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[opts.rerun&&pulls>=5||opts.afterQueueRerun&&armed?{...run,run_attempt:2,status:'in_progress',conclusion:null}:run]}]);
    if(last.includes('/jobs?'))return JSON.stringify([{jobs}]);
    if(last==='repos/'+repo+'/commits/'+sha('d'))
      return JSON.stringify({sha:sha('d'),parents:[{sha:sha('b')},{sha:sha('a')}],commit:{tree:{sha:sha('f')}}});
    if(last==='repos/'+repo+'/commits/'+sha('e'))
      return JSON.stringify({sha:sha('e'),parents:[{sha:opts.wrongSquashParent?sha('c'):sha('b')}],commit:{tree:{sha:sha('f')}}});
    if(last==='repos/'+repo+'/pulls/509')
      return JSON.stringify({number:509,merged:opts.depMerged??true,base:{ref:opts.depBase??'develop'},merge_commit_sha:sha('c')});
    if(last==='repos/'+repo+'/compare/'+sha('c')+'...'+sha('b'))
      return JSON.stringify({status:opts.depCompare??'ahead',merge_base_commit:{sha:opts.depMergeBase??sha('c')}});
    if(last==='repos/'+repo+'/pulls/510/files?per_page=100')
      return JSON.stringify([opts.files??[{filename:'README.md',status:'modified',sha:sha('c')}]]);
    throw Error('Unexpected mock query '+JSON.stringify(args));
  };
  query.loadCheckout=()=>({checkout,checkoutArtifact});
  return {query,calls,f};
}

test('dependency declarations are mandatory, unambiguous and same-repo',()=>{
  assert.deepEqual(parseDependencies('Depends-on: none'),[]);
  assert.deepEqual(parseDependencies('x\nDepends-on: #1, #2 #1'),[1,2]);
  for(const body of ['', 'Depends-on: #1\nDepends-on: none','Depends-on: other/repo#12',
    'Depends-on:','#3','Depends-on: #0','Depends-on: #3 / #4'])
    assert.throws(()=>parseDependencies(body),/Depends-on/);
});
test('review eligibility is separate from the mandatory Full CI activation preflight',()=>{
  const f=fixture();
  assert.deepEqual(autoMergeErrors(f),[]);
  assert(!Object.hasOwn(f.pr,'statusChecks'),'CI jobs must not be part of the eligibility input');
  assert.deepEqual(collectEligibility(repo,510,f.review,mock().query).errors,[]);
});
test('missing review, stale SHA or target changes fail closed',()=>{
  for(const change of [
    f=>f.review.reviewedHeadSha=sha('c'),
    f=>f.review.reviewedBaseSha=sha('c'),
    f=>f.review.reviewId='',
    f=>f.review.unresolved=['bad contract'],
    f=>f.review.conclusion='pending',
    f=>f.review.prNumber=511,
    f=>f.review.repo='someone/else',
    f=>f.pr.head.sha=sha('e'),
    f=>f.baseSha=sha('d')
  ]) {
    const f=fixture();change(f);
    assert(autoMergeErrors(f).length,'Should reject '+change);
  }
});
test('draft, conflicting, blocked, fork, wrong target and unmerged dependencies fail closed',()=>{
  const mutations=[
    f=>f.pr.draft=true,f=>f.pr.mergeable=false,f=>f.pr.mergeable=null,
    f=>f.pr.labels=[{name:'do-not-merge'}],
    f=>f.pr.head.repo.full_name='other/fork',
    f=>f.pr.base.ref='master',
    f=>f.dependencies=[{merged:false}],f=>f.settings.allow_auto_merge=false
  ];
  for(const change of mutations) {
    const f=fixture();change(f);assert(autoMergeErrors(f).length,'Should reject '+change);
  }
});
test('review status must be a real required check; CI and squash protection cannot be omitted',()=>{
  for(const change of [
    f=>f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks=
      f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks.filter(x=>x.context!==reviewContext),
    f=>f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks=
      f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks.filter(x=>x.context!=='inventory'),
    f=>f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks.find(x=>x.context===reviewContext).integration_id=15368,
    f=>f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.required_status_checks.find(x=>x.context==='check').integration_id=null,
    f=>f.ruleset.rules.find(r=>r.type==='pull_request').parameters.allowed_merge_methods.push('merge'),
    f=>f.ruleset.rules.find(r=>r.type==='pull_request').parameters.required_review_thread_resolution=false,
    f=>f.ruleset.enforcement='disabled',
    f=>f.ruleset.rules=f.ruleset.rules.filter(r=>r.type!=='required_linear_history')
  ]) {
    const f=fixture();change(f);assert(autoMergeErrors(f).length,'Must reject '+change);
  }
});
test('dependency resolution reads actual PRs, not a self-declared merged claim',()=>{
  const {f,query}=mock({depMerged:false});
  f.pr.body='Depends-on: #509';
  // Use a fresh mock that serves that body.
  const q=(...args)=>args.at(-1)==='repos/'+repo+'/pulls/510'?
    JSON.stringify(f.pr):query(...args);
  const evidence=collectEligibility(repo,510,f.review,q);
  assert(evidence.errors.some(e=>e.includes('prerequisite')));
});
test('low-risk waiver checks every changed file, not the authors declaration',()=>{
  const f=fixture();f.review={disposition:'low-risk-docs',reviewedHeadSha:sha('a'),reviewedBaseSha:sha('b')};
  assert(autoMergeErrors({...f,review:f.review,changedFiles:[{filename:'README.md',status:'modified',sha:sha('c')}]}).length===0);
  assert(autoMergeErrors({...f,review:f.review,changedFiles:[{filename:'scripts/run.mjs',status:'modified',sha:sha('c')}]}).length>0);
  assert(autoMergeErrors({...f,review:f.review,changedFiles:[]}).length>0);
});
test('dry run makes no writes; activation confirms pending review before enable and releases success only after queue validation',()=>{
  const a=mock();
  const dry=armAutoMerge(repo,510,a.f.review,a.query,{dryRun:true});
  assert.equal(dry.state,'eligible');
  assert(!a.calls.some(call=>call.includes('POST')||call[0]==='pr'));
  const b=mock();
  const r=armAutoMerge(repo,510,b.f.review,b.query);
  assert.equal(r.state,'auto-merge-requested');
  const write=b.calls.findIndex(call=>call.includes('POST')),merge=b.calls.findIndex(call=>call[1]==='graphql');
  assert(write>=0&&merge>write);
  assert(b.calls[write].includes('context='+reviewContext));
  assert(b.calls[write].includes('repos/'+repo+'/statuses/'+sha('a')));
  assert(b.calls[write].includes('state=pending'));
  assert(b.calls[merge].includes('head='+sha('a')));
  assert(b.calls[merge].includes('id=PR_reviewed_510'));
  assert(b.calls[merge].some(arg=>arg.includes('expectedHeadOid:$head,mergeMethod:SQUASH')));
  assert(b.calls.findIndex(call=>call.includes('state=success'))>merge);
  assert(!b.calls.some(c=>c[0]==='pr'&&c[1]==='merge'&&!c.includes('--disable-auto')),'no synchronous merge fallback');
});
test('a new HEAD or develop tip blocks status writes and merge even after an earlier pass',()=>{
  for(const [options,pattern] of [[{nextHead:sha('e')},/changed|stale/i],
    [{nextTarget:sha('e')},/changed|differs|stale/i],
    [{nextBase:sha('e')},/changed|differs/i]]) {
    const m=mock(options);
    assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),pattern);
    assert(!m.calls.some(call=>call.includes('POST')||call[0]==='pr'));
  }
});

test('arm proof embeds exact Full preflight and still requires later merge verification',()=>{
  const a=mock();
  const proof=armAutoMerge(repo,510,a.f.review,a.query,{dryRun:true}).proof;
  assert.equal(proof.schemaVersion,4);
  assert.equal(proof.kind,'auto-merge-arm');
  assert.equal(proof.tested,sha('d'));
  assert.equal(proof.sourceTree,sha('f'));
  assert.deepEqual(verifyAutoMergeArm(proof),[]);
  assert.deepEqual(verifyDelivery(proof),[]);
  for(const mutate of [
    p=>p.parents=[sha('b'),sha('e')],
    p=>p.head=sha('e'),
    p=>p.targetAfterSha=sha('e'),
    p=>p.review.reviewedHeadSha=sha('e'),
    p=>p.sourceTree='invalid',
    p=>p.review.unresolved=['unfinished'],
    p=>p.kind='preflight',
  ]) {
    const broken=structuredClone(proof);mutate(broken);
    assert(verifyAutoMergeArm(broken).length,'Reject '+mutate);
  }
});

test('inactive target scopes and non-strict base protection fail closed',()=>{
  for(const mutate of [f=>f.ruleset.target='tag',f=>f.ruleset.conditions.ref_name.exclude=['refs/heads/develop'],
    f=>f.ruleset.conditions.ref_name.exclude=['refs/heads/*'],f=>f.ruleset.conditions.ref_name.include=['~ALL'],
    f=>f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters.strict_required_status_checks_policy=false]) {
    const f=fixture();mutate(f);assert(autoMergeErrors(f).length,'Reject '+mutate);
  }
});
test('merged dependencies must target develop and be proven contained in the reviewed base',()=>{
  for(const dep of [{merged:true,base:{ref:'master'},contained:true},{merged:true,base:{ref:'develop'}},
    {merged:true,base:{ref:'develop'},contained:false}]) {
    assert(autoMergeErrors({...fixture(),dependencies:[dep]}).length);
  }
  assert.deepEqual(autoMergeErrors({...fixture(),dependencies:[{merged:true,base:{ref:'develop'},contained:true}]}),[]);
});
test('activation must be read back and failure revokes review success and native auto-merge',()=>{
  for(const options of [{missingAutoMerge:true},{mergeMethod:'merge'},{finalHold:true},{activationFails:true}]) {
    const m=mock(options);assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query));
    assert(m.calls.some(c=>c.includes('state=failure')),'Revoke status for '+JSON.stringify(options));
    assert(m.calls.some(c=>c.includes('--disable-auto')),'Cancel native queue for '+JSON.stringify(options));
  }
});

test('same-named Fast green contexts cannot authorize Full preflight',()=>{
  const m=mock({fastOnly:true});
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),/Full CI/);
  assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'));
});
test('attempt evidence is saved before status success and on cleanup failure',()=>{
  const m=mock({activationFails:true}),records=[];
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query,{persist:r=>records.push(r.state)}));
  assert.deepEqual(records,['prepared','authorizing','activation-failed']);
});

test('dependency collector proves squash ancestry in the actual develop ref',()=>{
  for(const [options,ok] of [[{},true],[{depBase:'master'},false],[{depCompare:'diverged'},false],
    [{depCompare:'behind'},false],[{depMergeBase:sha('e')},false]]) {
    const m=mock(options);m.f.pr.body='Depends-on: #509';
    const e=collectEligibility(repo,510,m.f.review,m.query);
    assert.equal(e.errors.length===0,ok,JSON.stringify(options));
  }
});
test('immediate merge readback verifies the actual squash parent and source tree',()=>{
  const good=mock({mergeImmediately:true});
  assert.equal(armAutoMerge(repo,510,good.f.review,good.query).state,'merged');
  const bad=mock({mergeImmediately:true,wrongSquashParent:true});
  assert.throws(()=>armAutoMerge(repo,510,bad.f.review,bad.query),/squash/);
});
test('missing Full proof cannot be relabeled into a valid authorization',()=>{
  const m=mock(),p=armAutoMerge(repo,510,m.f.review,m.query,{dryRun:true}).proof;
  for(const mutate of [p=>delete p.fullPreflight,p=>p.fullPreflight.schemaVersion=4,
    p=>p.fullPreflight.sourceTree=sha('e'),p=>p.fullPreflight.review={...p.fullPreflight.review,reviewId:'another'}]) {
    const broken=structuredClone(p);mutate(broken);assert(verifyAutoMergeArm(broken).length);
  }
});
test('revocation failures remain explicitly uncertain in the error and attempt journal',()=>{
  const m=mock({activationFails:true}),records=[];
  const query=(...args)=>{
    if(args.includes('state=failure')||args.includes('--disable-auto'))throw Error('cleanup transport error');
    return m.query(...args);
  };query.loadCheckout=m.query.loadCheckout;
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,query,{persist:r=>records.push(r)}),/revocation uncertain.*\n.*cancellation uncertain/s);
  assert.equal(records.at(-1).cleanup.length,2);
});

test('same-head rerun during final eligibility invalidates Full proof before authorization',()=>{
  const m=mock({rerun:true});
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),/Quality|Full/);
  assert(!m.calls.some(c=>c.includes('state=success')||c[0]==='pr'));
});
test('waiver normalizes API file ordering and optional identity metadata into valid proof',()=>{
  const files=['docs/research/z.md','README.md'].map(filename=>({filename,status:'modified',sha:sha('c')}));
  const m=mock({files});m.f.pr.changed_files=2;
  const review={disposition:'low-risk-docs',repo,prNumber:510,reviewedHeadSha:sha('a'),reviewedBaseSha:sha('b')};
  const p=armAutoMerge(repo,510,review,m.query,{dryRun:true}).proof;
  assert.deepEqual(p.changedFiles,p.fullPreflight.changedFiles);
  assert.deepEqual(verifyAutoMergeArm(p),[]);
});

test('last Full readback must retain complete PR identity before any remote mutation',()=>{
 for(const options of [{finalTarget:'master'},{finalNumber:511},{finalFork:true},{finalMergeCommit:true}]) {
  const m=mock(options);
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),/admission|identity|Full|changed/);
  assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'),'No mutation for '+JSON.stringify(options));
 }
});

test('independent review can arm while Full is pending without claiming Full success or downloading its artifact',()=>{
 const m=mock({pending:true});m.query.loadCheckout=()=>{throw Error('Pending CI has no passing checkout');};
 const result=armAutoMerge(repo,510,m.f.review,m.query);
 assert.equal(result.state,'auto-merge-requested');
 assert.equal(result.proof.fullPreflight,undefined);
 assert(!m.calls.some(c=>c[0]==='pr'&&!c.includes('--disable-auto')),'pending path cannot use CLI immediate-merge dispatch');
 const mutation=m.calls.find(c=>c[1]==='graphql');
 assert(mutation.includes('id=PR_reviewed_510'));assert(mutation.includes('head='+sha('a')));
 assert(mutation.some(c=>c.includes('expectedHeadOid:$head,mergeMethod:SQUASH')));
 assert.deepEqual(result.proof.pendingRun,{id:7,attempt:1,head:sha('a')});
 assert.deepEqual(verifyAutoMergeArm(result.proof),[]);
 assert(verifyDelivery(result.proof).some(e=>e.includes('not successful Full')));
 for(const mutate of [p=>p.pendingRun.head=sha('c'),p=>p.pendingRun.attempt=0,p=>delete p.pendingRun]){
  const broken=structuredClone(result.proof);mutate(broken);assert(verifyAutoMergeArm(broken).length);
 }
});
test('pending activation rejects known Full failure, a changed final identity and a new attempt',()=>{
 const failed=mock({pending:true,pendingFailure:true});
 assert.throws(()=>armAutoMerge(repo,510,failed.f.review,failed.query),/failed/);
 assert(!failed.calls.some(c=>c.includes('POST')||c[0]==='pr'));
 for(const mutate of [p=>p.base.ref='master',p=>p.head.repo.full_name='other/fork',p=>p.labels=['hold']]){
  const m=mock({pending:true});let reads=0;
  const query=(...args)=>{
   const result=m.query(...args);
   if(args.at(-1)===`repos/${repo}/pulls/510`&&++reads>=3){const p=JSON.parse(result);mutate(p);return JSON.stringify(p);}return result;
  };
  assert.throws(()=>armAutoMerge(repo,510,m.f.review,query),/changed/);
  assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'));
 }
 const m=mock({pending:true});let runs=0;
 const query=(...args)=>{const result=m.query(...args);if(args.at(-1).includes('/actions/workflows/')&&++runs>1){const p=JSON.parse(result);p[0].workflow_runs[0].run_attempt=2;return JSON.stringify(p);}return result;};
 assert.throws(()=>armAutoMerge(repo,510,m.f.review,query),/attempt changed/);
});
test('Full gate cannot be omitted or lose the Actions source when arming',()=>{
 for(const source of ['missing',null,123]){
  const f=fixture(),checks=f.ruleset.rules.find(r=>r.type==='required_status_checks').parameters;
  if(source==='missing')checks.required_status_checks=checks.required_status_checks.filter(c=>c.context!=='full-quality');
  else checks.required_status_checks.find(c=>c.context==='full-quality').integration_id=source;
  assert(autoMergeErrors(f).length);
 }
});
test('completed Full uses the same native handshake and never a bypass-capable synchronous fallback',()=>{
 const m=mock();assert.equal(m.f.pr.state,'open');
 assert.equal(armAutoMerge(repo,510,m.f.review,m.query).state,'auto-merge-requested');
 assert(m.calls.some(c=>c.includes('state=pending')));
 assert(!m.calls.some(c=>c[0]==='pr'&&c[1]==='merge'&&!c.includes('--disable-auto')));
});
test('overwritten review gate, replaced CI attempt and a merge before release are handshake failures',()=>{
 for(const options of [{overwrittenGate:true},{pending:true,afterQueueRerun:true},{mergeBeforeRelease:true},
  {activationFails:true},{missingAutoField:true,missingAutoMerge:true}]){
  const m=mock(options);assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query));
  assert(!m.calls.some(c=>c.includes('state=success')),'never release review success after a handshake failure');
  assert(m.calls.some(c=>c.includes('--disable-auto')));
  assert(m.calls.some(c=>c.includes('state=failure')));
 }
});
test('pause cancels native auto-merge before revoking review and refuses uncertain cancellation',()=>{
 for(const blocked of [false,true]){
  const f=fixture(),calls=[];let disabled=false;
  const query=(...args)=>{
   calls.push(args);if(args.at(-1)==='repos/'+repo)return JSON.stringify(f.settings);
   if(args[0]==='pr'){assert(args.includes('--disable-auto'));disabled=true;return '';}
   if(args.includes('POST'))return JSON.stringify({state:'failure',context:reviewContext});
   return JSON.stringify({...f.pr,auto_merge:disabled&&!blocked?null:{merge_method:'squash'}});
  };
  if(blocked){assert.throws(()=>pauseAutoMerge(repo,510,query),/not confirmed/);assert(!calls.some(c=>c.includes('POST')));}
  else{assert.equal(pauseAutoMerge(repo,510,query).state,'paused');assert(calls.findIndex(c=>c[0]==='pr')<calls.findIndex(c=>c.includes('POST')));}
 }
});
test('early authorization requires separate exact historical PR Full and actual push Full after merge',()=>{
 const m=mock(),completed=armAutoMerge(repo,510,m.f.review,m.query,{dryRun:true}).proof;
 const arm={...completed,pendingRun:{id:7,attempt:1,head:sha('a')}};delete arm.fullPreflight;
 const p=completed.fullPreflight;
 const historical={schemaVersion:5,kind:'historical-auto-full',...Object.fromEntries(['run','jobs','checkout','checkoutArtifact','testedCommit','currentRun'].map(key=>[key,p[key]]))};
 assert.deepEqual(verifyHistoricalAutoFull(historical,arm),[]);
 const detachedLink=structuredClone(historical);detachedLink.run.pull_requests=[];detachedLink.currentRun.pull_requests=[];
 assert.deepEqual(verifyHistoricalAutoFull(detachedLink,arm),[],'GitHub may clear PR association after merge; immutable checkout still binds the PR');
 detachedLink.checkout.prNumber=511;
 assert(verifyHistoricalAutoFull(detachedLink,arm).length,'empty API link must not permit a different artifact PR');
 const futureArm={...arm,pendingRun:{...arm.pendingRun,attempt:2}};
 assert(verifyHistoricalAutoFull(historical,futureArm).length,'older attempt cannot certify a newer authorization');
 const pushRun={...p.run,id:9,head_sha:sha('e'),event:'push',head_branch:'develop'};
 const pr={number:510,merged:true,state:'closed',head:{sha:arm.head},base:{ref:'develop'},merge_commit_sha:sha('e')};
 const e={schemaVersion:3,repo,preflight:arm,pr,current:pr,prFull:historical,
  commit:{sha:sha('e'),parents:[{sha:arm.base}],commit:{tree:{sha:arm.sourceTree}}},run:pushRun,currentRun:pushRun,
  jobs:p.jobs.map(j=>({...j,run_id:9,head_sha:sha('e')})),
  checkout:{...p.checkout,event:'push',runId:9,head:sha('e'),tested:sha('e'),parents:[arm.base]},
  checkoutArtifact:{id:250,name:'quality-9-1-check',expired:false,workflow_run:{id:9,head_sha:sha('e')}}};delete e.checkout.prNumber;
 assert.equal(verifyMergedDelivery(e).state,'merged_passed');
 for(const mutate of [e=>delete e.prFull,e=>e.prFull.jobs.pop(),e=>e.jobs.pop(),
  e=>e.prFull.checkout.base=sha('c'),e=>e.commit.parents=[{sha:sha('c')}],
  e=>e.prFull.currentRun.run_attempt=2,e=>e.prFull.checkoutArtifact.id=0]){
  const broken=structuredClone(e);mutate(broken);assert.equal(verifyMergedDelivery(broken).state,'merged_pending',String(mutate));
 }
});
test('merged collector accepts real empty PR links and selects the authorized source branch',()=>{
 const m=mock(),completed=armAutoMerge(repo,510,m.f.review,m.query,{dryRun:true}).proof;
 const arm={...completed,pendingRun:{id:7,attempt:1,head:sha('a')}};delete arm.fullPreflight;
 const p=completed.fullPreflight,branch='feat/reviewed-source';
 const pr={number:510,merged:true,state:'closed',head:{sha:arm.head,ref:branch},base:{ref:'develop'},merge_commit_sha:sha('e')};
 const prRun={...p.run,head_branch:branch,pull_requests:[]};
 const pushRun={...prRun,id:9,event:'push',head_sha:sha('e'),head_branch:'develop'};
 const query=(...args)=>{
  const endpoint=args.at(-1);
  if(endpoint.endsWith('/pulls/510'))return JSON.stringify(pr);
  if(endpoint.endsWith('/commits/'+sha('d')))return JSON.stringify(p.testedCommit);
  if(endpoint.endsWith('/commits/'+sha('e')))return JSON.stringify({sha:sha('e'),parents:[{sha:arm.base}],commit:{tree:{sha:arm.sourceTree}}});
  if(endpoint.includes('/actions/workflows/')&&endpoint.includes('event=pull_request'))return JSON.stringify([{workflow_runs:[prRun,{...prRun,id:8,head_branch:'feat/other-source'}]}]);
  if(endpoint.includes('/actions/workflows/')&&endpoint.includes('event=push'))return JSON.stringify([{workflow_runs:[pushRun]}]);
  if(endpoint.includes('/actions/runs/7/jobs'))return JSON.stringify([{jobs:p.jobs}]);
  if(endpoint.includes('/actions/runs/9/jobs'))return JSON.stringify([{jobs:p.jobs.map(j=>({...j,run_id:9,head_sha:sha('e')}))}]);
  throw Error('Unexpected query '+endpoint);
 };
 const evidence=collectMergedDelivery(repo,510,arm,query,(run)=>run.id===7?
  {checkout:p.checkout,checkoutArtifact:p.checkoutArtifact}:
  {checkout:{...p.checkout,prNumber:undefined,event:'push',runId:9,head:sha('e'),tested:sha('e'),parents:[arm.base]},
   checkoutArtifact:{id:250,name:'quality-9-1-check',expired:false,workflow_run:{id:9,head_sha:sha('e')}}});
 assert.deepEqual(evidence.prFull.run.pull_requests,[],'preserve actual API response');
 assert.equal(evidence.prFull.run.id,7);
 assert.equal(verifyMergedDelivery(evidence).state,'merged_passed');
});


test('migrated repository requires the canonical name and immutable repository ID together',()=>{
 assert.deepEqual(autoMergeErrors(fixture()),[]);
 for(const mutate of [f=>f.repo='CHNISam/Slay-the-Abyss',f=>f.repo='someone/Slay-the-Abyss',
  f=>f.settings.id=1429751263,f=>delete f.settings.id,f=>f.settings.id='1429751262',
  f=>f.settings.full_name='CHNISam/Slay-the-Abyss',f=>delete f.settings.full_name]){
  const f=fixture();mutate(f);assert(autoMergeErrors(f).some(e=>/repository/i.test(e)),String(mutate));
 }
});
test('arming and pausing refuse a replaced or unidentified repository before remote mutations',()=>{
 for(const identity of [{id:1429751263,full_name:repo},{id:1429751262,full_name:'CHNISam/Slay-the-Abyss'},
  {full_name:repo},{id:1429751262}]){
  for(const pause of [false,true]){
   const m=mock(),query=(...args)=>args.at(-1)==='repos/'+repo?
    JSON.stringify({...m.f.settings,id:undefined,full_name:undefined,...identity}):m.query(...args);
   query.loadCheckout=m.query.loadCheckout;
   assert.throws(()=>pause?pauseAutoMerge(repo,510,query):armAutoMerge(repo,510,m.f.review,query),/repository/i);
   assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'||c[1]==='graphql'),'no mutations for '+JSON.stringify(identity));
  }
 }
 const m=mock();
 assert.throws(()=>pauseAutoMerge('CHNISam/Slay-the-Abyss',510,m.query),/repository/i);
 assert.equal(m.calls.length,0,'legacy route must be rejected before querying it');
});
test('migration never rewrites legacy review or Full evidence into current authorization',()=>{
 const m=mock();m.f.review.repo='CHNISam/Slay-the-Abyss';
 assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),/different repository/);
 assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'||c[1]==='graphql'));
 const good=mock(),proof=armAutoMerge(repo,510,good.f.review,good.query,{dryRun:true}).proof;
 assert.deepEqual(verifyDelivery(proof),[]);
 const old=structuredClone(proof);old.fullPreflight.run.repository.full_name='CHNISam/Slay-the-Abyss';
 assert(verifyDelivery(old).length>0,'legacy run identity must not certify a current-repository proof');
});


test('all CLI entrypoints use the migrated canonical route, including pause and documentation waiver',()=>{
 assert.equal(repositoryFullName,'FurinyaWorks/Slay-the-Abyss');assert.equal(repositoryId,1429751262);
 const dir=mkdtempSync(join(tmpdir(),'auto-merge-migration-')),reviewPath=join(dir,'review.json');
 try{
  for(const mode of ['review','waiver','pause']){
   const m=mock({pending:true});writeFileSync(reviewPath,JSON.stringify(m.f.review));
   main(mode==='pause'?['510','--pause']:['510',mode==='review'?reviewPath:'--low-risk-docs','--dry-run'],m.query);
   assert(m.calls.some(c=>c.at(-1)==='repos/'+repo),'repository settings must be read');
   assert(!m.calls.some(c=>c.some(arg=>arg.includes('CHNISam/'))),'no legacy API route');
   if(mode==='pause')assert(m.calls.some(c=>c[0]==='pr'&&c.includes(repo)&&c.includes('--disable-auto')));
   else assert(!m.calls.some(c=>c.includes('POST')||c[0]==='pr'||c[1]==='graphql'),'dry run is read-only');
  }
 }finally{rmSync(dir,{recursive:true,force:true});}
});
