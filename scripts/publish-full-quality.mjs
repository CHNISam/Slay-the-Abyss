import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {currentFullQualityJobs,qualityWorkflowPath} from './verify-delivery.mjs';

export const fullQualityContext='full-quality';
const currentRun=e=>e.run?.id===e.runId&&e.run.run_attempt===e.attempt&&
 e.latestRun?.id===e.runId&&e.latestRun.run_attempt===e.attempt&&e.run.head_sha===e.head&&
 e.run.repository?.full_name===e.repo&&e.run.path===qualityWorkflowPath&&e.run.event==='pull_request'&&
 e.run.pull_requests?.some(p=>p.number===e.number);
export function fullGateErrors(e){
 const errors=[],sha=value=>/^[a-f0-9]{40}$/.test(value??'');
 if(e.mode!=='full')errors.push('Fast is feedback, not Full validation; request ci:full');
 for(const name of ['impact','rules','presentation','engineering-posix'])
  if(e.needs?.[name]?.result!=='success')errors.push('Full dependency is not successful: '+name);
 if(e.needs?.fast?.result!=='skipped')errors.push('Full must skip Fast');
 if(!Number.isSafeInteger(e.runId)||e.runId<1||!Number.isSafeInteger(e.attempt)||e.attempt<1||
  e.run?.id!==e.runId||e.run.run_attempt!==e.attempt||e.run.head_sha!==e.head||
  e.run.event!=='pull_request'||e.run.path!==qualityWorkflowPath||e.run.status!=='in_progress'||
  e.run.repository?.full_name!==e.repo||!e.run.pull_requests?.some(p=>p.number===e.number)||
  e.latestRun?.id!==e.runId||e.latestRun.run_attempt!==e.attempt)errors.push('Stale or invalid Full run/attempt');
 if(!sha(e.head)||!sha(e.base)||!sha(e.tested)||e.pr?.number!==e.number||e.pr.state!=='open'||e.pr.merged||
  e.pr.head?.sha!==e.head||e.pr.head.repo?.full_name!==e.repo||e.pr.base?.ref!=='develop'||
  e.pr.base.sha!==e.base||e.target!==e.base||e.pr.merge_commit_sha!==e.tested||
  e.commit?.sha!==e.tested||JSON.stringify(e.commit.parents?.map(p=>p.sha))!==JSON.stringify([e.base,e.head]))
  errors.push('Full tested merge differs from current HEAD/BASE');
 const ids=new Set(),identities=new Set();
 if(!Array.isArray(e.jobs))errors.push('Missing actual Full jobs');
 for(const job of e.jobs??[]){
  const key=job.name+':'+job.run_attempt;
  if(!currentFullQualityJobs.includes(job.name)||!Number.isSafeInteger(job.id)||job.id<1||ids.has(job.id)||
   identities.has(key)||job.run_id!==e.runId||job.head_sha!==e.head||!Number.isSafeInteger(job.run_attempt)||
   job.run_attempt<1||job.run_attempt>e.attempt)errors.push('Invalid Full job identity: '+job.name);
  ids.add(job.id);identities.add(key);
 }
 for(const name of currentFullQualityJobs){
  const job=(e.jobs??[]).filter(j=>j.name===name).sort((a,b)=>b.run_attempt-a.run_attempt)[0];
  if(name==='check'){
   if(job?.run_attempt!==e.attempt||job.status!=='in_progress'||job.conclusion!=null)errors.push('Not the current check aggregate');
  }else if(job?.status!=='completed'||job.conclusion!==(name==='fast'?'skipped':'success'))errors.push('Incomplete or failed Full job: '+name);
 }
 return errors;
}
export function publishFullQuality(e,query){
 // A superseded writer must not overwrite the new run's pending/success status
 // with an old failure, even when its always() aggregate finishes last.
 if(!currentRun(e))return {state:'superseded',errors:[]};
 const errors=fullGateErrors(e),state=errors.length?'failure':'success';
 publishStatus(e,state,errors.length?'Full unavailable: '+errors[0].slice(0,115):`Exact Full run ${e.runId}, attempt ${e.attempt}`,query);
 return {state,errors};
}
function publishStatus(e,state,description,query){
 const result=JSON.parse(query('api','--method','POST',`repos/${e.repo}/statuses/${e.head}`,
  '-f','state='+state,'-f','context='+fullQualityContext,'-f','description='+
  description,
  '-f',`target_url=https://github.com/${e.repo}/actions/runs/${e.runId}`));
 if(result.state!==state||result.context!==fullQualityContext)throw Error('Full status write readback differs');
}
export function beginFullQuality(e,query){
 if(!currentRun(e)||e.pr?.state!=='open'||e.pr.merged||e.pr.head?.sha!==e.head)
  return {state:'superseded',errors:[]};
 publishStatus(e,'pending',`Waiting for Full run ${e.runId}, attempt ${e.attempt}`,query);
 return {state:'pending',errors:[]};
}
function gh(...args){
 const result=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
 if(result.error||result.status!==0)throw Error('Full gate GitHub query failed: '+(result.error?.message??result.stderr));
 return result.stdout;
}
export function main(env=process.env,query=gh,{pending=false}={}){
 const event=JSON.parse(readFileSync(env.GITHUB_EVENT_PATH,'utf8')),prEvent=event.pull_request;
 if(env.GITHUB_EVENT_NAME!=='pull_request'||prEvent?.base?.ref!=='develop'||prEvent?.head?.repo?.full_name!==env.GITHUB_REPOSITORY)return;
 const repo=env.GITHUB_REPOSITORY,head=prEvent.head.sha,base=prEvent.base.sha,tested=env.GITHUB_SHA;
 const get=endpoint=>JSON.parse(query('api',`repos/${repo}/${endpoint}`));
 const pages=(endpoint,key)=>JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/${endpoint}`)).flatMap(p=>p[key]);
 const runId=Number(env.GITHUB_RUN_ID),attempt=Number(env.GITHUB_RUN_ATTEMPT),number=prEvent.number;
 const run=get('actions/runs/'+runId);
 const runs=pages(`actions/workflows/quality.yml/runs?event=pull_request&head_sha=${head}&per_page=100`,'workflow_runs');
 const latestRun=runs.filter(r=>r.head_sha===head&&r.pull_requests?.some(p=>p.number===number)).sort((a,b)=>b.id-a.id)[0];
 if(pending){console.log(JSON.stringify(beginFullQuality({repo,head,runId,attempt,number,run,latestRun,pr:get('pulls/'+number)},query)));return;}
 const jobs=pages(`actions/runs/${runId}/jobs?filter=all&per_page=100`,'jobs');
 const evidence={repo,head,base,tested,runId,attempt,number,mode:env.FULL_MODE,needs:JSON.parse(env.FULL_NEEDS),
  run,jobs,latestRun,pr:get('pulls/'+number),target:get('git/ref/heads/develop').object?.sha,commit:get('commits/'+tested)};
 const result=publishFullQuality(evidence,query);console.log(JSON.stringify(result));
 // A Fast result is expected feedback. Its original required checks keep their
 // meaning, but the separate Full status cannot authorize automatic merging.
 if(result.errors.length&&evidence.mode==='full')throw Error(result.errors.join('\n'));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{main(process.env,gh,{pending:process.argv[2]==='--pending'});}catch(error){console.error(error.message);process.exitCode=1;}
}
