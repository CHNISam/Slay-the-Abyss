import test from 'node:test';
import assert from 'node:assert/strict';
import {parseDependencies,autoMergeErrors,collectEligibility,armAutoMerge,reviewContext,requiredContexts} from '../scripts/arm-auto-merge.mjs';

const sha=c=>c.repeat(40);
const repo='CHNISam/Slay-the-Abyss';
function fixture() {
  const pr={number:510,state:'open',merged:false,draft:false,mergeable:true,changed_files:1,
    head:{sha:sha('a'),repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},body:'Summary\n\nDepends-on: none',
    labels:[]};
  const review={reviewId:'independent-agent-evidence-100',reviewedHeadSha:sha('a'),
    reviewedBaseSha:sha('b'),conclusion:'pass',unresolved:[],repo,prNumber:510};
  const settings={allow_auto_merge:true};
  const ruleset={enforcement:'active',conditions:{ref_name:{include:['refs/heads/develop']}},
    rules:[
      {type:'pull_request',parameters:{allowed_merge_methods:['squash'],required_review_thread_resolution:true}},
      {type:'required_linear_history'},
      {type:'required_status_checks',parameters:{strict_required_status_checks_policy:false,
        required_status_checks:requiredContexts.map(context=>({context}))}}
    ]};
  return {pr,review,settings,ruleset,repo,baseSha:sha('b'),dependencies:[]};
}
function mock(opts={}) {
  const f=fixture(),calls=[];let pulls=0,armed=false;
  const query=(...args)=>{
    calls.push(args);
    if(args[0]==='pr') {
      if(args[1]==='merge') {armed=true;return '';}
      throw Error('Unexpected gh pr invocation');
    }
    const last=args.includes('--method')?args.find(x=>x.startsWith('repos/')):args.at(-1);
    if(args.includes('POST'))return '{"state":"success"}';
    if(last==='repos/'+repo+'/pulls/510') {
      ++pulls;
      const pr=structuredClone(f.pr);
      if(opts.nextHead&&pulls>=2)pr.head.sha=opts.nextHead;
      if(opts.nextBase&&pulls>=2)pr.base.sha=opts.nextBase;
      if(armed&&opts.mergeImmediately)pr.merged=true;
      return JSON.stringify(pr);
    }
    if(last==='repos/'+repo)return JSON.stringify(f.settings);
    if(last==='repos/'+repo+'/rulesets/25870651')return JSON.stringify(f.ruleset);
    if(last==='repos/'+repo+'/git/ref/heads/develop')
      return JSON.stringify({ref:'refs/heads/develop',object:{type:'commit',sha:opts.nextTarget&&pulls>=2?opts.nextTarget:f.baseSha}});
    if(last==='repos/'+repo+'/pulls/509')
      return JSON.stringify({number:509,merged:opts.depMerged??true});
    if(last==='repos/'+repo+'/pulls/510/files?per_page=100')
      return JSON.stringify([[{filename:'README.md',status:'modified',sha:sha('c')}]]);
    throw Error('Unexpected mock query '+JSON.stringify(args));
  };
  return {query,calls,f};
}

test('dependency declarations are mandatory, unambiguous and same-repo',()=>{
  assert.deepEqual(parseDependencies('Depends-on: none'),[]);
  assert.deepEqual(parseDependencies('x\nDepends-on: #1, #2 #1'),[1,2]);
  for(const body of ['', 'Depends-on: #1\nDepends-on: none','Depends-on: other/repo#12',
    'Depends-on:','#3','Depends-on: #0','Depends-on: #3 / #4'])
    assert.throws(()=>parseDependencies(body),/Depends-on/);
});
test('a reviewed HEAD and a guarded ruleset qualify without waiting for CI results',()=>{
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
    [{nextTarget:sha('e')},/changed|differs/i],
    [{nextBase:sha('e')},/changed|differs/i]]) {
    const m=mock(options);
    assert.throws(()=>armAutoMerge(repo,510,m.f.review,m.query),pattern);
    assert(!m.calls.some(call=>call.includes('POST')||call[0]==='pr'));
  }
});
