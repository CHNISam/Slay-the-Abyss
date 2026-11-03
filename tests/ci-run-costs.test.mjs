import test from 'node:test';
import assert from 'node:assert/strict';
import {runCost,summarizeCosts} from '../scripts/ci-run-costs.mjs';
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
