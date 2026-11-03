// Offline analysis of unmodified GitHub REST run/job responses. Not billing data.
import {readFileSync,readdirSync,writeFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const seconds=(from,to)=>{
  const a=Date.parse(from),b=Date.parse(to);
  return Number.isFinite(a)&&Number.isFinite(b)&&b>=a?(b-a)/1000:null;
};
const actual=job=>Number.isSafeInteger(job.runner_id)&&job.runner_id>0
  && job.steps?.some(step=>step.name==='Set up job');
const latest=values=>values.filter(Boolean).sort().at(-1)??null;
export function runCost(run,response,{inventoryRun,inventoryJobs}={}) {
  if(!Array.isArray(response.jobs)||response.total_count!==response.jobs.length)throw Error('Incomplete jobs response');
  const ids=new Set();
  for(const job of response.jobs) {
    if(ids.has(job.id))throw Error('Duplicate job');
    ids.add(job.id);
    if(job.run_id!==run.id||job.run_attempt!==run.run_attempt||job.head_sha!==run.head_sha)throw Error('Job/run identity mismatch');
  }
  const jobs=response.jobs.map(job=>({id:job.id,name:job.name,status:job.status,conclusion:job.conclusion,
    createdAt:job.created_at??null,startedAt:job.started_at??null,completedAt:job.completed_at??null,
    runnerId:job.runner_id,runnerName:job.runner_name,executed:actual(job),
    queueSeconds:actual(job)?seconds(job.created_at,job.started_at):null,
    executionSeconds:actual(job)?seconds(job.started_at,job.completed_at):null,
    steps:(job.steps??[]).map(step=>({name:step.name,conclusion:step.conclusion,
      seconds:step.conclusion==='skipped'?0:seconds(step.started_at,step.completed_at)}))}));
  const fast=jobs.filter(job=>/^fast \([^)]+\)$/.test(job.name)&&job.executed);
  const full=jobs.filter(job=>/^rules \(\d+\/\d+\)$/.test(job.name)&&job.executed);
  const mode=fast.length?'fast':full.length?'full':'unresolved';
  const required=['check','engineering-posix','presentation'];
  const gates=required.map(name=>jobs.find(job=>job.name===name));
  const qualitySuccess=run.conclusion==='success'&&gates.every(job=>job?.conclusion==='success'
    &&seconds(run.created_at,response.jobs.find(raw=>raw.id===job.id)?.completed_at)!==null);
  const qualityEnd=qualitySuccess?latest(required.map(name=>response.jobs.find(job=>job.name===name)?.completed_at)):null;
  const inventory=Array.isArray(inventoryJobs?.jobs)&&inventoryJobs.total_count===inventoryJobs.jobs.length
    ?inventoryJobs.jobs.find(job=>job.name==='inventory'):undefined;
  const inventoryMatches=inventoryRun?.head_sha===run.head_sha&&inventoryRun?.event===run.event
    &&inventoryRun?.head_branch===run.head_branch&&inventory?.run_id===inventoryRun?.id
    &&inventory?.run_attempt===inventoryRun?.run_attempt&&inventory?.head_sha===run.head_sha;
  const requiredEnd=qualityEnd&&inventoryMatches&&inventoryRun.conclusion==='success'&&inventory.conclusion==='success'
    &&seconds(run.created_at,inventory.completed_at)!==null
    ?latest([qualityEnd,inventory.completed_at]):null;
  const completed=jobs.filter(job=>job.executionSeconds!==null);
  const pullRequests=(run.pull_requests??[]).map(pr=>pr.number);
  const platforms=Object.fromEntries(['windows','posix','other'].map(platform=>{
    const group=jobs.filter(job=>job.executed&&(platform==='windows'?/^(rules \(|fast \(windows)/.test(job.name)
      :platform==='posix'?/^(engineering-posix \(|fast \(ubuntu)/.test(job.name)
      :!/^(rules \(|engineering-posix \(|fast \((?:windows|ubuntu))/.test(job.name)));
    return [platform,{jobs:group.length,knownExecutionRunnerMinutes:group.reduce((n,j)=>n+(j.executionSeconds??0),0)/60,
      unknownExecutionJobs:group.filter(j=>j.executionSeconds===null).map(j=>j.id),
      knownQueueSecondsSum:group.reduce((n,j)=>n+(j.queueSeconds??0),0),
      unknownQueueJobs:group.filter(j=>j.queueSeconds===null).map(j=>j.id)}];
  }));
  return {id:run.id,attempt:run.run_attempt,sha:run.head_sha,event:run.event,branch:run.head_branch,pullRequests,platforms,
    status:run.status,conclusion:run.conclusion,createdAt:run.created_at,mode,
    qualitySuccess,qualityWallSeconds:seconds(run.created_at,qualityEnd),
    inventoryRunId:inventoryMatches?inventoryRun.id:null,
    requiredWallSeconds:seconds(run.created_at,requiredEnd),
    runWallSeconds:run.status==='completed'?seconds(run.created_at,run.updated_at):null,
    knownJobQueueSecondsSum:jobs.reduce((n,job)=>n+(job.queueSeconds??0),0),
    completedExecutionRunnerMinutes:completed.reduce((n,job)=>n+job.executionSeconds,0)/60,
    executionStillOpen:jobs.filter(job=>job.executed&&job.executionSeconds===null).map(job=>job.id),
    queueUnknown:jobs.filter(job=>job.executed&&job.queueSeconds===null).map(job=>job.id),
    fastPrEligible:run.event==='pull_request'&&run.run_attempt===1&&pullRequests.length===1&&requiredEnd!==null&&fast.length===2
      &&fast.some(job=>job.name==='fast (windows-2025)')&&fast.some(job=>job.name==='fast (ubuntu-24.04)')
      &&fast.every(job=>job.conclusion==='success')&&full.length===0,
    jobs};
}
export function summarizeCosts(runs) {
  const percentile=(values,p)=>values.length?[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1]:null;
  const fast=runs.filter(run=>run.fastPrEligible),distinct=new Set(fast.map(run=>`${run.pullRequests[0]}:${run.sha}`));
  if(distinct.size!==fast.length)throw Error('Duplicate run sample');
  const values=fast.map(run=>run.requiredWallSeconds);
  return {runs:runs.length,naturalFastPrSamples:fast.length,fastTargetSampleCount:20,
    fastSampleSufficient:fast.length>=20,fastP50Seconds:percentile(values,.5),fastP90Seconds:percentile(values,.9),
    successfulFullRuns:runs.filter(run=>run.mode==='full'&&run.qualitySuccess).length,
    cancelledRuns:runs.filter(run=>run.conclusion==='cancelled').length,
    cancelledCompletedExecutionRunnerMinutes:runs.filter(run=>run.conclusion==='cancelled')
      .reduce((n,run)=>n+run.completedExecutionRunnerMinutes,0),
    limitations:['Required wall remains unknown unless separate inventory run matches SHA, event, branch and attempt job identity',
      'Elapsed runner-minutes are not billed minutes or platform multipliers',
      'Job queue sum overlaps across jobs and must not be added to wall time',
      'No open job time inferred; no cancelled matrix placeholder counted as execution',
      'Compare workflow/selector identities before treating samples as one performance cohort'],runs};
}
export function analyzeDirectory(directory) {
  const pages=readdirSync(directory).filter(name=>/^quality-runs-\d+\.json$/.test(name));
  const runs=pages.flatMap(name=>JSON.parse(readFileSync(join(directory,name))).workflow_runs);
  const seen=new Set(),costs=[];
  const inventoryRuns=readdirSync(directory).filter(name=>/^licenses-runs-\d+\.json$/.test(name))
    .flatMap(name=>JSON.parse(readFileSync(join(directory,name))).workflow_runs);
  for(const run of runs) {
    if(seen.has(run.id))throw Error('Duplicate run in collected pages');seen.add(run.id);
    const file=join(directory,`jobs-${run.id}.json`);
    let source;try{source=readFileSync(file);}catch(error){if(error.code==='ENOENT')continue;throw error;}
    const matches=inventoryRuns.filter(other=>other.head_sha===run.head_sha&&other.event===run.event&&other.head_branch===run.head_branch);
    const inventoryRun=matches.length===1?matches[0]:undefined;
    const inventoryFile=inventoryRun?join(directory,`license-jobs-${inventoryRun.id}.json`):null;
    let inventoryJobs;
    if(inventoryFile)try{inventoryJobs=JSON.parse(readFileSync(inventoryFile));}catch(error){if(error.code!=='ENOENT')throw error;}
    costs.push(runCost(run,JSON.parse(source),{inventoryRun,inventoryJobs}));
  }
  const inventoryCosts=[];
  for(const run of inventoryRuns) {
    const file=join(directory,`license-jobs-${run.id}.json`);
    let source;try{source=readFileSync(file);}catch(error){if(error.code==='ENOENT')continue;throw error;}
    inventoryCosts.push(runCost(run,JSON.parse(source)));
  }
  return {...summarizeCosts(costs),listedRuns:runs.length,uncollectedRuns:runs.length-costs.length,inventoryCosts};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if(process.argv.length!==4)throw Error('Usage: ci-run-costs.mjs <raw-directory> <output.json>');
    writeFileSync(process.argv[3],JSON.stringify(analyzeDirectory(process.argv[2]),null,2)+'\n');
  }catch(error){console.error(error.message);process.exitCode=1;}
}
