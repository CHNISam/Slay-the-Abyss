import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {runCost,summarizeCosts,analyzeDirectory} from '../scripts/ci-run-costs.mjs';
const run={id:1,run_attempt:1,head_sha:'a'.repeat(40),pull_requests:[{number:42}],event:'pull_request',status:'completed',conclusion:'success',created_at:'2026-11-03T00:00:00Z',updated_at:'2026-11-03T00:10:00Z'};
const job=(id,name,extra={})=>({id,name,run_id:1,run_attempt:1,head_sha:run.head_sha,runner_id:id,runner_name:'GitHub Actions',status:'completed',conclusion:'success',created_at:'2026-11-03T00:00:00Z',started_at:'2026-11-03T00:01:00Z',completed_at:'2026-11-03T00:02:00Z',steps:[{name:'Set up job',conclusion:'success'}],...extra});
const jobs=()=>[job(1,'check'),job(2,'engineering-posix'),job(3,'presentation'),job(4,'fast (ubuntu-24.04)'),job(5,'fast (windows-2025)')];
const response=list=>({total_count:list.length,jobs:list});
const inventory={inventoryRun:run,inventoryJobs:response([job(7,'inventory')])};
test('natural Fast requires actual two-platform Quality execution, not cancelled placeholders or advisory',()=>{
  assert.equal(runCost(run,response(jobs()),inventory).fastPrEligible,true);
  assert.equal(runCost(run,response(jobs())).fastPrEligible,false);
  assert.equal(runCost(run,response(jobs()),{inventoryRun:{...run,head_sha:'b'.repeat(40)},inventoryJobs:inventory.inventoryJobs}).requiredWallSeconds,null);
  assert.equal(runCost(run,response(jobs()),{inventoryRun:run,inventoryJobs:response([job(7,'inventory',{completed_at:null})])}).requiredWallSeconds,null);
  const duplicatePlatform=jobs();duplicatePlatform[4].name='fast (ubuntu-24.04)';assert.equal(runCost(run,response(duplicatePlatform),inventory).fastPrEligible,false);
  assert.equal(runCost(run,response(jobs()),{inventoryRun:run,inventoryJobs:{...inventory.inventoryJobs,total_count:2}}).requiredWallSeconds,null);
  for(const name of ['fast','Quick feedback (windows-2025)','advisory']) {
    const r=runCost({...run,conclusion:'cancelled'},response([job(1,name,{runner_id:0,conclusion:'cancelled',steps:[]})]));
    assert.equal(r.fastPrEligible,false);assert.equal(r.mode,'unresolved');assert.equal(r.completedExecutionRunnerMinutes,0);
  }
  assert.equal(runCost({...run,event:'workflow_dispatch'},response(jobs())).fastPrEligible,false);
  assert.equal(runCost({...run,pull_requests:[]},response(jobs())).fastPrEligible,false);
});
test('queue, wall, actual execution and unfinished/cancelled costs stay separate',()=>{
  const r=runCost(run,response(jobs()));assert.equal(r.qualityWallSeconds,120);
  assert.equal(r.knownJobQueueSecondsSum,300);assert.equal(r.completedExecutionRunnerMinutes,5);
  const open=runCost({...run,status:'in_progress',conclusion:null},response([job(1,'rules (1/13)',{completed_at:null,status:'in_progress',conclusion:null})]));
  assert.deepEqual(open.executionStillOpen,[1]);assert.equal(open.completedExecutionRunnerMinutes,0);assert.equal(open.runWallSeconds,null);
  assert.deepEqual(open.platforms.windows.unknownExecutionJobs,[1]);assert.equal(open.platforms.windows.knownExecutionRunnerMinutes,0);
});
test('missing, failed, skipped or cancelled gates never become successful Fast measurements',()=>{
  for(const conclusion of ['failure','skipped','cancelled',null]) {
    const list=jobs();list[0].conclusion=conclusion;assert.equal(runCost(run,response(list)).fastPrEligible,false);
  }
  assert.equal(runCost(run,response(jobs().slice(1))).qualityWallSeconds,null);
  const list=jobs();list[0].completed_at=null;assert.equal(runCost(run,response(list)).qualityWallSeconds,null);
});
test('incomplete pages and wrong attempt/SHA/job identities reject rather than manufacture samples',()=>{
  assert.throws(()=>runCost(run,{total_count:6,jobs:jobs()}),/Incomplete/);
  for(const extra of [{run_id:2},{run_attempt:2},{head_sha:'b'.repeat(40)}])assert.throws(()=>runCost(run,response([job(1,'check',extra)])),/identity/);
  assert.throws(()=>runCost(run,response([job(1,'check'),job(1,'presentation')])),/Duplicate/);
});
test('insufficient natural samples remain insufficient; nearest rank is reported only from eligible runs',()=>{
  const r=runCost(run,response(jobs()),inventory),s=summarizeCosts([r]);assert.equal(s.naturalFastPrSamples,1);assert.equal(s.fastSampleSufficient,false);assert.equal(s.fastP90Seconds,120);
  assert.equal(summarizeCosts([]).fastP50Seconds,null);assert.throws(()=>summarizeCosts([r,r]),/Duplicate/);
  const cancelled={...r,id:2,conclusion:'cancelled',fastPrEligible:false};assert.equal(summarizeCosts([cancelled]).cancelledCompletedExecutionRunnerMinutes,5);
  const synthetic=Array.from({length:20},(_,i)=>({...r,id:i+1,sha:i.toString(16).padStart(40,'0'),requiredWallSeconds:(i+1)*10}));
  const ranked=summarizeCosts(synthetic);assert.equal(ranked.fastSampleSufficient,true);assert.equal(ranked.fastP50Seconds,100);assert.equal(ranked.fastP90Seconds,180);
});

// These fixtures exercise the offline observer, never GitHub write permissions.
const policy=()=>({id:25870651,enforcement:'active',updated_at:'2026-11-04T00:00:00Z',
  conditions:{ref_name:{include:['refs/heads/develop'],exclude:[]}},rules:[
    {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,
      required_status_checks:[{context:'check'},{context:'full-quality',integration_id:15368},{context:'independent-review'}]}},
    {type:'merge_queue',parameters:{max_entries_to_build:1,max_entries_to_merge:1}}]});
const codes=summary=>summary.harnessFeedback?.findings.map(finding=>finding.code);
const cost=()=>runCost(run,response(jobs()),inventory);
test('feedback sample success never becomes an unmeasured delivery or multi-agent outcome',()=>{
  const summary=summarizeCosts([cost()]);
  assert.ok(summary.harnessFeedback,'missing end-to-end harness feedback');
  assert.equal(summary.harnessFeedback.deliveryAcceptance,'UNVERIFIED');
  assert.equal(summary.harnessFeedback.safeMergeSamples,null);
  assert.equal(summary.harnessFeedback.independentAgentDeliveries,null);
  assert.equal(summary.harnessFeedback.playableProductOutcomes,null);
  assert.equal(summary.harnessFeedback.policySnapshot.status,'unobserved');
  assert.equal(summary.feedbackWallScope,'Quality aggregates plus inventory; excludes independent review, full-quality and merge completion');
});
test('supplied Full gate and serial queue become actionable findings, not automatic rule changes',()=>{
  const ruleset=policy(),before=structuredClone(ruleset),summary=summarizeCosts([cost()],{ruleset});
  assert.ok(codes(summary)?.includes('FULL_GATE_REQUIRES_ROUTE_REVIEW'));
  assert.ok(codes(summary).includes('SINGLE_QUEUE_BUILD'));
  assert.ok(codes(summary).includes('STRICT_BASE_WITH_QUEUE'));
  assert.equal(summary.harnessFeedback.policySnapshot.ruleId,25870651);
  assert.equal(summary.harnessFeedback.policySnapshot.scope,'supplied snapshot only; not historical or complete effective policy');
  assert.equal(summary.harnessFeedback.deliveryAcceptance,'UNVERIFIED');
  assert.deepEqual(ruleset,before);
});
test('removing Full or increasing queue concurrency does not self-certify a working Fast merge route',()=>{
  const ruleset=policy();ruleset.rules[0].parameters.required_status_checks=[{context:'check'}];
  ruleset.rules[1].parameters.max_entries_to_build=2;
  const summary=summarizeCosts([cost()],{ruleset});
  assert.equal(codes(summary)?.includes('FULL_GATE_REQUIRES_ROUTE_REVIEW'),false);
  assert.equal(codes(summary).includes('SINGLE_QUEUE_BUILD'),false);
  assert.equal(summary.harnessFeedback.deliveryAcceptance,'UNVERIFIED');
});
test('only exact active develop snapshots are interpreted; malformed or ambiguous snapshots reject',()=>{
  for(const change of [p=>{p.id=null;},p=>{p.enforcement='disabled';},
    p=>{p.conditions.ref_name.include=['refs/heads/master'];},
    p=>{p.conditions.ref_name.exclude=['refs/heads/develop'];},
    p=>{p.rules[0].parameters.required_status_checks=null;},
    p=>{p.rules[0].parameters.strict_required_status_checks_policy='true';},
    p=>{p.rules.push(structuredClone(p.rules[0]));},
    p=>{p.rules[1].parameters.max_entries_to_build=0;}]) {
    const ruleset=policy();change(ruleset);
    assert.throws(()=>summarizeCosts([cost()],{ruleset}),/ruleset/i);
  }
});
test('last completed execution exposes queue versus work without summing overlapping queue times',()=>{
  const list=[job(1,'check'),job(2,'engineering-posix'),job(3,'presentation'),
    job(4,'rules (1/16)',{started_at:'2026-11-03T00:01:00Z',completed_at:'2026-11-03T00:24:00Z'}),
    job(5,'engineering-posix (12/12)',{started_at:'2026-11-03T00:22:00Z',completed_at:'2026-11-03T00:34:00Z'})];
  const summary=summarizeCosts([runCost(run,response(list),inventory)]);
  assert.ok(summary.harnessFeedback);
  const timing=summary.harnessFeedback.runTimings[0];
  assert.equal(timing.lastCompletedExecution.id,5);
  assert.equal(timing.lastCompletedExecution.queueSeconds,1320);
  assert.equal(timing.lastCompletedExecution.executionSeconds,720);
  assert.equal(timing.lastCompletedExecution.finishAfterRunCreatedSeconds,2040);
  assert.equal(timing.longestQueue.id,5);
  assert.equal(timing.longestExecution.id,4);
  assert.equal(timing.longestExecution.executionSeconds,1380);
});
test('placeholders and unfinished work cannot manufacture a completed critical path',()=>{
  const list=[job(1,'rules (1/16)',{runner_id:0,steps:[],conclusion:'cancelled'}),
    job(2,'rules (2/16)',{status:'in_progress',conclusion:null,completed_at:null})];
  const summary=summarizeCosts([runCost({...run,status:'in_progress',conclusion:null},response(list))]);
  assert.ok(summary.harnessFeedback);
  assert.equal(summary.harnessFeedback.runTimings[0].lastCompletedExecution,null);
  assert.equal(summary.harnessFeedback.runTimings[0].longestExecution,null);
});
test('Full budget uses measured aggregate completion, not updated_at, and keeps unknowns visible',()=>{
  const full={...cost(),mode:'full',fastPrEligible:false,requiredWallSeconds:1801,runWallSeconds:6000};
  const summary=summarizeCosts([full,{...full,id:2,requiredWallSeconds:null}]);
  assert.ok(summary.harnessFeedback);
  assert.deepEqual(summary.harnessFeedback.fullOverBudget,[{runId:1,attempt:1,seconds:1801}]);
  assert.deepEqual(summary.harnessFeedback.fullTimingUnknown,[{runId:2,attempt:1}]);
  assert.equal(summarizeCosts([{...full,requiredWallSeconds:1800}]).harnessFeedback.fullOverBudget.length,0);
});
test('failed, cancelled and unfinished runs remain visible beside successful samples',()=>{
  const r=cost();const summary=summarizeCosts([r,{...r,id:2,fastPrEligible:false,conclusion:'failure',completedExecutionRunnerMinutes:7},
    {...r,id:3,fastPrEligible:false,conclusion:'cancelled'},
    {...r,id:4,fastPrEligible:false,status:'in_progress',conclusion:null,completedExecutionRunnerMinutes:2}]);
  assert.deepEqual(summary.runOutcomes,{success:1,failure:1,cancelled:1,in_progress:1});
  assert.equal(summary.failedCompletedExecutionRunnerMinutes,7);
  assert.equal(summary.cancelledCompletedExecutionRunnerMinutes,5);
  assert.equal(summary.allCompletedExecutionRunnerMinutes,19);
  assert.equal(summary.naturalFastPrSamples,1);
});

const rawDirectory=t=>{
  const directory=mkdtempSync(join(tmpdir(),'ci-cost-feedback-'));
  t.after(()=>rmSync(directory,{recursive:true,force:true}));
  writeFileSync(join(directory,'quality-runs-1.json'),JSON.stringify({workflow_runs:[run]}));
  writeFileSync(join(directory,'jobs-1.json'),JSON.stringify(response(jobs())));
  return directory;
};
test('existing directory entry reports missing policy and uncollected runs without inventing completeness',t=>{
  const directory=rawDirectory(t);
  writeFileSync(join(directory,'quality-runs-1.json'),JSON.stringify({workflow_runs:[run,{...run,id:2}]}));
  const result=analyzeDirectory(directory);
  assert.equal(result.uncollectedRuns,1);
  assert.equal(result.harnessFeedback?.policySnapshot.status,'unobserved');
  assert.ok(codes(result).includes('UNCOLLECTED_RUNS'));
});
test('existing CLI reads an optional raw ruleset snapshot without adding a separate command or network request',t=>{
  const directory=rawDirectory(t),output=join(directory,'report.json');
  writeFileSync(join(directory,'ruleset-develop.json'),JSON.stringify(policy()));
  const result=spawnSync(process.execPath,[fileURLToPath(new URL('../scripts/ci-run-costs.mjs',import.meta.url)),directory,output],{encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);
  const report=JSON.parse(readFileSync(output,'utf8'));
  assert.ok(codes(report)?.includes('FULL_GATE_REQUIRES_ROUTE_REVIEW'));
  assert.equal(report.harnessFeedback.deliveryAcceptance,'UNVERIFIED');
});
test('a present but unreadable or invalid ruleset is an error, never an absent policy',t=>{
  const directory=rawDirectory(t);
  for(const text of ['{broken','null',JSON.stringify({...policy(),enforcement:'disabled'})]) {
    writeFileSync(join(directory,'ruleset-develop.json'),text);
    assert.throws(()=>analyzeDirectory(directory));
  }
});
