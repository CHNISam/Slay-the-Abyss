import test from 'node:test';
import assert from 'node:assert/strict';
import {parseDependencies,autoMergeErrors,collectEligibility,armAutoMerge as activate,reviewContext,requiredContexts} from '../scripts/arm-auto-merge.mjs';
import {verifyAutoMergeArm,verifyDelivery,currentFullQualityJobs,qualityWorkflowPath} from '../scripts/verify-delivery.mjs';

const sha=c=>c.repeat(40);
const armAutoMerge=(repo,number,review,query,options={})=>activate(repo,number,review,query,{loadCheckout:query.loadCheckout,...options});
const repo='CHNISam/Slay-the-Abyss';
function fixture() {
  const pr={number:510,state:'open',merged:false,draft:false,mergeable:true,changed_files:1,
    head:{sha:sha('a'),repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},merge_commit_sha:sha('d'),body:'Summary\n\nDepends-on: none',
    labels:[]};
  const review={reviewId:'independent-agent-evidence-100',reviewedHeadSha:sha('a'),
    reviewedBaseSha:sha('b'),conclusion:'pass',unresolved:[],repo,prNumber:510};
  const settings={allow_auto_merge:true,allow_squash_merge:true};
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
  const f=fixture(),calls=[];let pulls=0,armed=false;
  const run={id:7,run_attempt:1,event:'pull_request',head_sha:sha('a'),path:qualityWorkflowPath,
    repository:{full_name:repo},status:'completed',conclusion:'success',pull_requests:[{number:510}]};
  const jobs=currentFullQualityJobs.map((name,i)=>({id:100+i,name,status:'completed',
    conclusion:name==='fast'?'skipped':'success',run_attempt:1,run_id:7,head_sha:sha('a')}));
  if(opts.fastOnly)jobs.find(j=>j.name.startsWith('rules')).conclusion='skipped';
  const checkout={schemaVersion:1,attempt:1,event:'pull_request',runId:7,prNumber:510,
    head:sha('a'),base:sha('b'),tested:sha('d'),parents:[sha('b'),sha('a')]};
  const checkoutArtifact={id:200,name:'quality-7-1-check',expired:false,workflow_run:{id:7,head_sha:sha('a')}};
  const query=(...args)=>{
    calls.push(args);
    if(args[0]==='pr') {
      if(args[1]==='merge') {if(args.includes('--disable-auto'))return '';if(opts.activationFails)throw Error('activation failed');armed=true;return '';}
      throw Error('Unexpected gh pr invocation');
    }
    const last=args.includes('--method')?args.find(x=>x.startsWith('repos/')):args.at(-1);
    if(args.includes('POST'))return '{"state":"success"}';
    if(last==='repos/'+repo+'/pulls/510') {
      ++pulls;
      const pr=structuredClone(f.pr);
      if(opts.nextHead&&pulls>=2)pr.head.sha=opts.nextHead;
      if(opts.nextBase&&pulls>=2)pr.base.sha=opts.nextBase;
      if(armed&&opts.mergeImmediately){pr.merged=true;pr.state='closed';pr.merge_commit_sha=sha('e');}
      if(armed&&!opts.missingAutoMerge)pr.auto_merge={merge_method:opts.mergeMethod??'squash'};
      if(armed&&opts.finalHold){pr.labels=['hold'];pr.base.sha=sha('e');}
      return JSON.stringify(pr);
    }
    if(last==='repos/'+repo)return JSON.stringify(f.settings);
    if(last==='repos/'+repo+'/rulesets/25870651')return JSON.stringify(f.ruleset);
    if(last==='repos/'+repo+'/git/ref/heads/develop')
      return JSON.stringify({ref:'refs/heads/develop',object:{type:'commit',sha:opts.nextTarget&&pulls>=2?opts.nextTarget:f.baseSha}});
    if(last.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[opts.rerun&&pulls>=5?{...run,run_attempt:2,status:'in_progress',conclusion:null}:run]}]);
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
test('dry run makes no writes, while approved activation writes status before arming exact HEAD',()=>{
  const a=mock();
  const dry=armAutoMerge(repo,510,a.f.review,a.query,{dryRun:true});
  assert.equal(dry.state,'eligible');
  assert(!a.calls.some(call=>call.includes('POST')||call[0]==='pr'));
  const b=mock();
  const r=armAutoMerge(repo,510,b.f.review,b.query);
  assert.equal(r.state,'auto-merge-requested');
  const write=b.calls.findIndex(call=>call.includes('POST')),merge=b.calls.findIndex(call=>call[0]==='pr');
  assert(write>=0&&merge>write);
  assert(b.calls[write].includes('context='+reviewContext));
  assert(b.calls[write].includes('repos/'+repo+'/statuses/'+sha('a')));
  assert(b.calls[merge].includes('--match-head-commit'));
  assert(b.calls[merge].includes(sha('a')));
  assert(b.calls[merge].includes('--auto'));
  assert(b.calls[merge].includes('--squash'));
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
  assert.deepEqual(records,['prepared','authorizing','authorized','activation-failed']);
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
