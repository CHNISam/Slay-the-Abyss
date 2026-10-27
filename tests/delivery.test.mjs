import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { verifyDelivery, verifyMergedDelivery, collectMergedDelivery, fullQualityJobs, qualityWorkflowPath } from '../scripts/verify-delivery.mjs';

const sha = letter => letter.repeat(40);
function mergedEvidence() {
  const preflight={schemaVersion:2,repo:'owner/repo',head:sha('a'),base:sha('b'),tested:sha('c'),sourceTree:sha('d'),baseRef:'develop',runId:7,attempt:2,
    event:'pull_request',prNumber:8,parents:[sha('b'),sha('a')],
    checkout:{head:sha('a'),base:sha('b'),tested:sha('c'),runId:7,attempt:2,event:'pull_request',prNumber:8,parents:[sha('b'),sha('a')]},
    testedCommit:{sha:sha('c'),parents:[{sha:sha('b')},{sha:sha('a')}],commit:{tree:{sha:sha('d')}}},
    run:{id:7,run_attempt:2,event:'pull_request',head_sha:sha('a'),path:qualityWorkflowPath,repository:{full_name:'owner/repo'},status:'completed',conclusion:'success',pull_requests:[{number:8}]},
    jobs:fullQualityJobs.map(name=>({name,status:'completed',conclusion:'success',run_attempt:2,run_id:7,head_sha:sha('a')})),
    review:{reviewedHeadSha:sha('a'),reviewedBaseSha:sha('b'),reviewId:'external-session-123',conclusion:'pass',unresolved:[]}};
  const pr={number:8,merged:true,state:'closed',head:{sha:sha('a')},base:{ref:'develop',sha:sha('f')},merge_commit_sha:sha('e')};
  preflight.currentRun=structuredClone(preflight.run);
  const evidence={schemaVersion:2,repo:'owner/repo',preflight,pr,current:structuredClone(pr),commit:{sha:sha('e'),parents:[{sha:sha('b')}],commit:{tree:{sha:sha('d')}}},
    run:{id:9,run_attempt:3,event:'push',head_sha:sha('e'),head_branch:'develop',path:qualityWorkflowPath,repository:{full_name:'owner/repo'},status:'completed',conclusion:'success'},
    jobs:preflight.jobs.map(j=>({...j,run_attempt:3,run_id:9,head_sha:sha('e')})),
    checkout:{event:'push',runId:9,attempt:3,tested:sha('e'),head:sha('e'),base:sha('b'),parents:[sha('b')]}};
  evidence.currentRun=structuredClone(evidence.run);return evidence;
}

test('normal delivery includes the current complete hosted Quality matrices',()=>{
  const workflow=readFileSync(qualityWorkflowPath,'utf8');
  assert.match(workflow,/shard: \$\{\{ fromJSON\(inputs.runner_pool == 'local-special' && '\[1\]' \|\| '\[1,2,3,4,5,6,7,8\]'\) \}\}/);
  assert.match(workflow,/engineering-posix-shards:[\s\S]*?shard: \[1, 2, 3, 4\]/);
  assert.deepEqual(fullQualityJobs.filter(name=>name.startsWith('engineering-posix (')),
    Array.from({length:4},(_,i)=>`engineering-posix (${i+1}/4)`));
  assert.equal(fullQualityJobs.length,15);
});

test('post-merge delivery binds the actual squash commit, source tree and its own full Quality run',()=>{
  const evidence=mergedEvidence();
  assert.deepEqual(verifyDelivery(evidence.preflight),[]);
  assert.deepEqual(verifyMergedDelivery(evidence),{state:'merged_passed',errors:[]});
  // A later develop push does not rewrite the identity of this already-merged commit.
  assert.notEqual(evidence.pr.base.sha,evidence.preflight.base);
});

test('PR green alone leaves the merged commit pending verification',()=>{
  const evidence=mergedEvidence();delete evidence.run;delete evidence.checkout;evidence.jobs=[];
  const result=verifyMergedDelivery(evidence);
  assert.equal(result.state,'merged_pending');assert.match(result.errors.join('\n'),/Quality/);
  evidence.run={id:7,run_attempt:2,event:'pull_request',head_sha:sha('a'),head_branch:'feature',status:'completed',conclusion:'success'};
  evidence.jobs=evidence.preflight.jobs;evidence.checkout=evidence.preflight.checkout;
  assert.equal(verifyMergedDelivery(evidence).state,'merged_pending');
});

test('post-merge delivery rejects base advancement after preflight even if the resulting tree is unchanged',()=>{
  const evidence=mergedEvidence();evidence.commit.parents=[{sha:sha('f')}];
  evidence.checkout.base=sha('f');evidence.checkout.parents=[sha('f')];
  assert.match(verifyMergedDelivery(evidence).errors.join('\n'),/verified base/);
});

test('post-merge identity, source tree, latest attempt and every Quality job fail closed',()=>{
  const mutations=[
    ['unmerged PR',e=>e.pr.merged=false],['wrong PR',e=>e.pr.number++],
    ['wrong repository',e=>e.repo='other/repo'],['old preflight schema',e=>e.preflight.schemaVersion=1],
    ['changed head',e=>e.pr.head.sha=sha('f')],['changed target',e=>e.pr.base.ref='master'],
    ['wrong merge commit',e=>e.pr.merge_commit_sha=sha('f')],['wrong tree',e=>e.commit.commit.tree.sha=sha('f')],
    ['unbound source tree',e=>delete e.preflight.sourceTree],['multiple parents',e=>e.commit.parents.push({sha:sha('a')})],
    ['unresolved preflight review',e=>e.preflight.review.unresolved.push('finding')],
    ['unbound tested commit',e=>delete e.preflight.testedCommit],['unbound PR workflow',e=>e.preflight.run.path='.github/workflows/other.yml'],
    ['unbound merged workflow',e=>e.run.path='.github/workflows/other.yml'],['another run repository',e=>e.run.repository.full_name='other/repo'],
    ['diagnostic run',e=>e.run.event='workflow_dispatch'],
    ['old combination green',e=>e.run.head_sha=e.preflight.tested],['different branch',e=>e.run.head_branch='master'],
    ['PR run reused',e=>e.run.event='pull_request'],['incomplete run',e=>e.run.status='in_progress'],
    ['failed run',e=>e.run.conclusion='failure'],['old attempt',e=>e.run.run_attempt++],
    ['missing required job',e=>e.jobs.shift()],['duplicate required job',e=>e.jobs.push({...e.jobs[0]})],
    ['missing shard',e=>e.jobs.pop()],['preflight missing shard',e=>e.preflight.jobs.pop()],
    ['cancelled shard',e=>e.jobs.at(-1).conclusion='cancelled'],['skipped shard',e=>e.jobs.at(-1).conclusion='skipped'],
    ['stale shard',e=>e.jobs.at(-1).run_attempt=2],['wrong checkout',e=>e.checkout.tested=sha('f')],
    ['stale receipt',e=>e.checkout.runId=7],['wrong receipt parent',e=>e.checkout.parents=[sha('f')]],
    ['PR changed during query',e=>e.current.merge_commit_sha=sha('f')],
    ['new attempt during query',e=>e.currentRun.run_attempt++],['new run during query',e=>e.currentRun.id++],
    ['preflight rerun during query',e=>e.preflight.currentRun.run_attempt++],
  ];
  for(const [name,mutate] of mutations){
    const evidence=mergedEvidence();mutate(evidence);
    const result=verifyMergedDelivery(evidence);
    assert.equal(result.state,'merged_pending',name);assert(result.errors.length,name);
  }
});

test('preflight also rejects unsuccessful extra Quality shards rather than trusting only aggregate names',()=>{
  const evidence=mergedEvidence().preflight;
  evidence.jobs.push({name:'rules (8/8)',status:'completed',conclusion:'skipped',run_attempt:2});
  assert(verifyDelivery(evidence).length);
});

test('PR jobs must belong to the exact run and head even when their attempt and green status match',()=>{
  for(const name of fullQualityJobs){
    for(const [field,value] of [['run_id',6],['head_sha',sha('f')],['run_id',undefined],['head_sha',undefined]]){
      const e=mergedEvidence().preflight;
      const job=e.jobs.find(job=>job.name===name);job[field]=value;
      assert(verifyDelivery(e).length,`${name}: ${field}=${value}`);
    }
  }
});

test('merged push jobs cannot borrow same-attempt green jobs from another run or commit',()=>{
  for(const name of fullQualityJobs){
    for(const [field,value] of [['run_id',8],['head_sha',sha('f')],['run_id',undefined],['head_sha',undefined]]){
      const e=mergedEvidence();
      const job=e.jobs.find(job=>job.name===name);job[field]=value;
      assert.equal(verifyMergedDelivery(e).state,'merged_pending',`${name}: ${field}=${value}`);
    }
  }
});

test('post-merge collector selects only the latest exact push run and all current-attempt job pages',()=>{
  const e=mergedEvidence(),calls=[];
  const query=(...args)=>{
    calls.push(args);
    const endpoint=args.at(-1);
    if(endpoint.endsWith('/pulls/8'))return JSON.stringify(e.pr);
    if(endpoint.endsWith(`/commits/${sha('e')}`))return JSON.stringify(e.commit);
    if(endpoint.includes('/actions/workflows/quality.yml/runs?'))return JSON.stringify([
      {workflow_runs:[{...e.run,id:8,run_attempt:1},{...e.run,id:10,event:'pull_request'}]},
      {workflow_runs:[{...e.run,id:11,head_sha:sha('f')},e.run]},
    ]);
    if(endpoint.endsWith('/actions/runs/9/attempts/3/jobs?per_page=100'))return JSON.stringify([{jobs:e.jobs.slice(0,2)},{jobs:e.jobs.slice(2)}]);
    throw Error(`Unexpected query ${args}`);
  };
  const actual=collectMergedDelivery('owner/repo',8,e.preflight,query,run=>{
    assert.equal(run.id,9);assert.equal(run.run_attempt,3);return e.checkout;
  });
  assert.deepEqual(verifyMergedDelivery(actual),{state:'merged_passed',errors:[]});
  assert.equal(calls.filter(args=>args.at(-1).endsWith('/pulls/8')).length,2);
  assert(calls.some(args=>args.includes('--paginate')&&args.at(-1).includes('/attempts/3/jobs')));
});

test('newer in-progress merged run cannot borrow an earlier successful push',()=>{
  const e=mergedEvidence();
  const query=(...args)=>{
    const path=args.at(-1);
    if(path.includes('/pulls/'))return JSON.stringify(e.pr);
    if(path.includes('/commits/'))return JSON.stringify(e.commit);
    if(path.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[e.run,{...e.run,id:10,status:'in_progress',conclusion:null}]}]);
    throw Error('Pending run must not download a receipt or request old jobs');
  };
  const actual=collectMergedDelivery('owner/repo',8,e.preflight,query,()=>{throw Error('No receipt until completion');});
  assert.equal(actual.run.id,10);assert.equal(verifyMergedDelivery(actual).state,'merged_pending');
});

test('post-merge collection rechecks the latest attempt after reading all evidence',()=>{
  const e=mergedEvidence();let lists=0;
  const query=(...args)=>{
    const path=args.at(-1);
    if(path.includes('/pulls/'))return JSON.stringify(e.pr);
    if(path.includes('/commits/'))return JSON.stringify(e.commit);
    if(path.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[++lists===1?e.run:{...e.run,run_attempt:4,status:'in_progress',conclusion:null}]}]);
    if(path.includes('/attempts/3/jobs?'))return JSON.stringify([{jobs:e.jobs}]);
    throw Error(`Unexpected query ${path}`);
  };
  const actual=collectMergedDelivery('owner/repo',8,e.preflight,query,()=>e.checkout);
  assert.equal(actual.run.run_attempt,3);assert.equal(actual.currentRun.run_attempt,4);
  assert.equal(verifyMergedDelivery(actual).state,'merged_pending');
});

test('absent push CI stays pending and never downloads the PR artifact',()=>{
  const e=mergedEvidence();
  const query=(...args)=>{
    const path=args.at(-1);
    if(path.includes('/pulls/'))return JSON.stringify(e.pr);
    if(path.includes('/commits/'))return JSON.stringify(e.commit);
    if(path.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[]}]);
    throw Error(`Unexpected query ${path}`);
  };
  const actual=collectMergedDelivery('owner/repo',8,e.preflight,query,()=>{throw Error('Must not borrow any artifact');});
  assert.equal(actual.commit.sha,e.pr.merge_commit_sha);assert.equal(actual.run,undefined);
  assert.equal(verifyMergedDelivery(actual).state,'merged_pending');
});

test('malformed evidence is rejected rather than upgraded by a claimed pass status',()=>{
  for(const value of [null,undefined,{},'passed'])assert(verifyDelivery(value).length);
  const e=mergedEvidence();e.state='merged_passed';e.jobs=null;
  assert.equal(verifyMergedDelivery(e).state,'merged_pending');
  const partial=mergedEvidence();partial.jobs=[null];partial.commit.parents={};
  assert.equal(verifyMergedDelivery(partial).state,'merged_pending');
});

test('delivery accepts exact merge parents and rejects stale reviews, attempts and missing jobs',async()=>{
  const evidence=mergedEvidence().preflight;
  assert.deepEqual(verifyDelivery(evidence),[]);
  for(const mutate of [e=>e.head='d'.repeat(40),e=>e.base='d'.repeat(40),e=>e.jobs.pop(),e=>e.jobs[0].conclusion='skipped',e=>e.attempt++,e=>e.parents.reverse(),e=>e.review.unresolved=['open bug'],e=>e.checkout.tested=e.head]) {
    const bad=structuredClone(evidence);mutate(bad);assert(verifyDelivery(bad).length>0);
  }
});
