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
// Observation only: this never publishes status, changes a rule or grants admission.
function policyFeedback(ruleset) {
  if(ruleset===undefined)return {status:'unobserved'};
  const refs=ruleset?.conditions?.ref_name,rules=ruleset?.rules;
  const checks=Array.isArray(rules)?rules.filter(rule=>rule?.type==='required_status_checks'):[];
  const queues=Array.isArray(rules)?rules.filter(rule=>rule?.type==='merge_queue'):[];
  const parameters=checks[0]?.parameters,contexts=parameters?.required_status_checks;
  const queue=queues[0]?.parameters;
  if(!Number.isSafeInteger(ruleset?.id)||ruleset.id<=0||ruleset.enforcement!=='active'
    ||!Array.isArray(refs?.include)||refs.include.length!==1||refs.include[0]!=='refs/heads/develop'
    ||!Array.isArray(refs.exclude)||refs.exclude.length!==0||checks.length!==1||queues.length>1
    ||typeof parameters?.strict_required_status_checks_policy!=='boolean'
    ||!Array.isArray(contexts)||contexts.length===0||contexts.some(check=>typeof check?.context!=='string'||!check.context.trim())
    ||new Set(contexts.map(check=>check.context)).size!==contexts.length
    ||queues.length===1&&(!Number.isSafeInteger(queue?.max_entries_to_build)||queue.max_entries_to_build<1
      ||!Number.isSafeInteger(queue?.max_entries_to_merge)||queue.max_entries_to_merge<1))
    throw Error('Invalid or ambiguous active develop ruleset snapshot');
  return {status:'observed',scope:'supplied snapshot only; not historical or complete effective policy',
    ruleId:ruleset.id,updatedAt:ruleset.updated_at??null,requiredContexts:contexts.map(check=>check.context),
    strictBase:parameters.strict_required_status_checks_policy,queueBuildConcurrency:queue?.max_entries_to_build??null,
    queueMergeBatch:queue?.max_entries_to_merge??null};
}
function executionTiming(run) {
  const completed=run.jobs.filter(job=>job.executed&&job.executionSeconds!==null
    &&seconds(run.createdAt,job.completedAt)!==null);
  const select=(jobs,key)=>jobs.reduce((best,job)=>best===null||key(job)>key(best)?job:best,null);
  const describe=job=>job?{id:job.id,name:job.name,queueSeconds:job.queueSeconds,executionSeconds:job.executionSeconds,
    finishAfterRunCreatedSeconds:seconds(run.createdAt,job.completedAt)}:null;
  return {runId:run.id,attempt:run.attempt,
    lastCompletedExecution:describe(select(completed,job=>seconds(run.createdAt,job.completedAt))),
    longestExecution:describe(select(completed,job=>job.executionSeconds)),
    longestQueue:describe(select(run.jobs.filter(job=>job.executed&&job.queueSeconds!==null),job=>job.queueSeconds))};
}
function harnessFeedback(runs,ruleset) {
  const policySnapshot=policyFeedback(ruleset),findings=[];
  const add=(code,nextEvidence)=>findings.push({code,nextEvidence});
  if(policySnapshot.status==='unobserved')add('POLICY_UNOBSERVED','Collect the active develop ruleset; missing data is not a permissive policy.');
  if(policySnapshot.requiredContexts?.includes('full-quality'))
    add('FULL_GATE_REQUIRES_ROUTE_REVIEW','Check selector, status publisher and Required policy together; Fast feedback alone does not satisfy a Full gate.');
  if(policySnapshot.queueBuildConcurrency===1)
    add('SINGLE_QUEUE_BUILD','Measure two independent PRs before claiming parallel integration; do not infer single-run latency from build concurrency.');
  if(policySnapshot.strictBase&&policySnapshot.queueBuildConcurrency!==null)
    add('STRICT_BASE_WITH_QUEUE','Review exact-base coordinator assumptions and real invalidations before changing Strict or queue settings.');
  const full=runs.filter(run=>run.mode==='full'&&run.qualitySuccess);
  const fullOverBudget=full.filter(run=>Number.isFinite(run.requiredWallSeconds)&&run.requiredWallSeconds>1800)
    .map(run=>({runId:run.id,attempt:run.attempt,seconds:run.requiredWallSeconds}));
  const fullTimingUnknown=full.filter(run=>!Number.isFinite(run.requiredWallSeconds))
    .map(run=>({runId:run.id,attempt:run.attempt}));
  if(fullOverBudget.length)add('FULL_OVER_BUDGET','Compare exact tests, platform, queue and execution costs; do not raise deadlines or remove coverage.');
  if(fullTimingUnknown.length)add('FULL_TIMING_UNKNOWN','Collect matching inventory evidence; updated_at is not a substitute for gate completion.');
  return {deliveryAcceptance:'UNVERIFIED',safeMergeSamples:null,independentAgentDeliveries:null,playableProductOutcomes:null,
    policySnapshot,fullBudgetSeconds:1800,fullOverBudget,fullTimingUnknown,runTimings:runs.map(executionTiming),findings,
    limitations:['Feedback observations are not merged_passed, product acceptance or a comparable before/after experiment',
      'A supplied ruleset is not applied retrospectively to runs; other effective rules and collection freshness remain unverified',
      'Last completed execution is an observation, not proof of a dependency critical path or the cause of runner waiting']};
}
export function summarizeCosts(runs,{ruleset}={}) {
  const percentile=(values,p)=>values.length?[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1]:null;
  const fast=runs.filter(run=>run.fastPrEligible),distinct=new Set(fast.map(run=>`${run.pullRequests[0]}:${run.sha}`));
  if(distinct.size!==fast.length)throw Error('Duplicate run sample');
  const values=fast.map(run=>run.requiredWallSeconds);
  const outcomes=new Map();
  for(const run of runs){const outcome=run.conclusion??run.status??'unknown';outcomes.set(outcome,(outcomes.get(outcome)??0)+1);}
  return {runs:runs.length,naturalFastPrSamples:fast.length,fastTargetSampleCount:20,
    feedbackWallScope:'Quality aggregates plus inventory; excludes independent review, full-quality and merge completion',
    harnessFeedback:harnessFeedback(runs,ruleset),runOutcomes:Object.fromEntries(outcomes),
    allCompletedExecutionRunnerMinutes:runs.reduce((n,run)=>n+run.completedExecutionRunnerMinutes,0),
    failedCompletedExecutionRunnerMinutes:runs.filter(run=>run.conclusion==='failure').reduce((n,run)=>n+run.completedExecutionRunnerMinutes,0),
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
  let ruleset;
  try{ruleset=JSON.parse(readFileSync(join(directory,'ruleset-develop.json'),'utf8'));}
  catch(error){if(error.code!=='ENOENT')throw error;}
  const summary=summarizeCosts(costs,{ruleset}),uncollectedRuns=runs.length-costs.length;
  if(uncollectedRuns)summary.harnessFeedback.findings.push({code:'UNCOLLECTED_RUNS',
    nextEvidence:'Collect missing job responses; this subset cannot establish complete run outcomes or total cost.'});
  return {...summary,listedRuns:runs.length,uncollectedRuns,inventoryCosts};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if(process.argv.length!==4)throw Error('Usage: ci-run-costs.mjs <raw-directory> <output.json>');
    writeFileSync(process.argv[3],JSON.stringify(analyzeDirectory(process.argv[2]),null,2)+'\n');
  }catch(error){console.error(error.message);process.exitCode=1;}
}
