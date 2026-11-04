import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fullGateErrors,publishFullQuality} from '../scripts/publish-full-quality.mjs';
import {currentFullQualityJobs,qualityWorkflowPath} from '../scripts/verify-delivery.mjs';
import {beforeAutoMergeWorkflow} from './helpers/auto-merge-workflow.mjs';
const sha=c=>c.repeat(40),repo='CHNISam/Slay-the-Abyss';
function fixture(){return {repo,runId:7,attempt:1,number:510,head:sha('a'),base:sha('b'),tested:sha('d'),mode:'full',
 needs:{impact:{result:'success'},rules:{result:'success'},fast:{result:'skipped'},presentation:{result:'success'},'engineering-posix':{result:'success'}},
 run:{id:7,run_attempt:1,event:'pull_request',head_sha:sha('a'),path:qualityWorkflowPath,status:'in_progress',repository:{full_name:repo},pull_requests:[{number:510}]},
 jobs:currentFullQualityJobs.map((name,i)=>({id:i+100,name,run_id:7,run_attempt:1,head_sha:sha('a'),status:name==='check'?'in_progress':'completed',conclusion:name==='check'?null:name==='fast'?'skipped':'success'})),
 latestRun:{id:7,run_attempt:1},pr:{number:510,state:'open',merged:false,head:{sha:sha('a'),repo:{full_name:repo}},base:{ref:'develop',sha:sha('b')},merge_commit_sha:sha('d')},
 target:sha('b'),commit:{sha:sha('d'),parents:[{sha:sha('b')},{sha:sha('a')}]}};}
test('Full gate accepts the exact running aggregate only after every actual shard succeeds',()=>assert.deepEqual(fullGateErrors(fixture()),[]));
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
test('Full publication reuses existing jobs and grants status writes only to planner and final aggregate',()=>{
 const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
 const jobs=[...workflow.slice(workflow.indexOf('\njobs:\n')).matchAll(/^  ([\w-]+):\n([\s\S]*?)(?=^  [\w-]+:|(?![\s\S]))/gm)];
 assert.deepEqual(jobs.map(j=>j[1]),['impact','fast','rules','check','presentation','engineering-posix-shards','engineering-posix']);
 for(const [,name,body]of jobs){
  if(['impact','check'].includes(name))assert.match(body,/^    permissions:\n      contents: read\n      statuses: write$/m);
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
 const drift=workflow.replace('timeout-minutes: 20','timeout-minutes: 21');
 assert(beforeAutoMergeWorkflow(drift).includes('timeout-minutes: 21'),'unrelated regression must remain visible to old guards');
});
