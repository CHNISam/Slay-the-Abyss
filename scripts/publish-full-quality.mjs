import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {resolve,join,sep} from 'node:path';
import {pathToFileURL} from 'node:url';
import {currentFullQualityJobs,qualityWorkflowPath,checkoutReceipt,receiptErrors} from './verify-delivery.mjs';

export const fullQualityContext='full-quality';
const currentRun=e=>e.run?.id===e.runId&&e.run.run_attempt===e.attempt&&
 e.latestRun?.id===e.runId&&e.latestRun.run_attempt===e.attempt&&e.run.head_sha===e.head&&
 e.run.repository?.full_name===e.repo&&e.run.path===qualityWorkflowPath&&e.run.event==='pull_request'&&
 e.run.pull_requests?.some(p=>p.number===e.number);
export function fullGateErrors(e,{metadataOnly=false}={}){
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
 if(!metadataOnly){
  const c=e.checkout??{};
  errors.push(...receiptErrors(c,e.checkoutArtifact,e.jobs,e.run,3));
  for(const [key,value]of Object.entries({runId:e.runId,head:e.head,base:e.base,tested:e.tested,prNumber:e.number,event:'pull_request'}))
   if(c[key]!==value)errors.push('Actual checkout receipt differs from Full source: '+key);
  if(JSON.stringify(c.parents)!==JSON.stringify([e.base,e.head]))errors.push('Actual checkout parent order differs from Full source');
  if(e.receiptError)errors.push('Checkout receipt collection failed: '+e.receiptError);
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
function obtainReceipt(repo,run,jobs,query){
 const directory=mkdtempSync(join(tmpdir(),'abyss-full-gate-'));
 try{return checkoutReceipt(repo,run,jobs,directory,query,3,{allowRunningAggregate:true});}
 finally{
  if(!resolve(directory).startsWith(resolve(tmpdir())+sep+'abyss-full-gate-'))throw Error('Unexpected receipt temporary path');
  rmSync(directory,{recursive:true,force:true});
 }
}
export function main(env=process.env,query=gh,{pending=false,loadCheckout}={}){
 const event=JSON.parse(readFileSync(env.GITHUB_EVENT_PATH,'utf8')),prEvent=event.pull_request;
 if(env.GITHUB_EVENT_NAME!=='pull_request'||prEvent?.base?.ref!=='develop'||prEvent?.head?.repo?.full_name!==env.GITHUB_REPOSITORY)return;
 const repo=env.GITHUB_REPOSITORY,head=prEvent.head.sha,base=prEvent.base.sha,tested=env.GITHUB_SHA;
 const get=endpoint=>JSON.parse(query('api',`repos/${repo}/${endpoint}`));
 const pages=(endpoint,key)=>JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/${endpoint}`)).flatMap(p=>p[key]);
 const runId=Number(env.GITHUB_RUN_ID),attempt=Number(env.GITHUB_RUN_ATTEMPT),number=prEvent.number;
 const run=get('actions/runs/'+runId);
 const latest=()=>pages(`actions/workflows/quality.yml/runs?event=pull_request&head_sha=${head}&per_page=100`,'workflow_runs')
  .filter(r=>r.head_sha===head&&r.pull_requests?.some(p=>p.number===number)).sort((a,b)=>b.id-a.id)[0];
 const latestRun=latest();
 if(pending){console.log(JSON.stringify(beginFullQuality({repo,head,runId,attempt,number,run,latestRun,pr:get('pulls/'+number)},query)));return;}
 const jobs=pages(`actions/runs/${runId}/jobs?filter=all&per_page=100`,'jobs');
 const evidence={repo,head,base,tested,runId,attempt,number,mode:env.FULL_MODE,needs:JSON.parse(env.FULL_NEEDS),
  run,jobs,latestRun,pr:get('pulls/'+number),target:get('git/ref/heads/develop').object?.sha,commit:get('commits/'+tested)};
 if(currentRun(evidence)&&fullGateErrors(evidence,{metadataOnly:true}).length===0){
  try{Object.assign(evidence,(loadCheckout??((r,j)=>obtainReceipt(repo,r,j,query)))(run,jobs));}
  catch(error){evidence.receiptError=error.message;}
 }
 // Downloads can outlast a rerun start. Re-read the actual latest attempt
 // before deciding whether this writer is still allowed to touch the status.
 evidence.latestRun=latest();
 const result=publishFullQuality(evidence,query);console.log(JSON.stringify(result));
 // A Fast result is expected feedback. Its original required checks keep their
 // meaning, but the separate Full status cannot authorize automatic merging.
 if(result.errors.length&&evidence.mode==='full')throw Error(result.errors.join('\n'));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{main(process.env,gh,{pending:process.argv[2]==='--pending'});}catch(error){console.error(error.message);process.exitCode=1;}
}
