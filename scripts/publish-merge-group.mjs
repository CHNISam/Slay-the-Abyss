import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {checkoutReceipt,receiptErrors,currentFullQualityJobs,qualityWorkflowPath} from './verify-delivery.mjs';
import {collectQueueAdmission} from './merge-queue-admission.mjs';
import {queueRulesAttested} from './merge-queue-policy.mjs';

const expectedRepo='FurinyaWorks/Slay-the-Abyss';
const contexts=['check','presentation','engineering-posix','inventory','full-quality','independent-review'];
const sha=value=>typeof value==='string'&&/^[0-9a-f]{40}$/.test(value);
const id=value=>Number.isSafeInteger(value)&&value>0;

// GitHub creates merge groups only from PRs admitted under the required PR
// checks. This is a queue-admission attestation, NOT an independent review of
// the speculative combined tree; the latter must pass the complete Full suite.
export function queueEventErrors(event,env) {
 const group=event?.merge_group,errors=[];
 if(env.GITHUB_EVENT_NAME!=='merge_group'||event?.action!=='checks_requested'||
  event?.repository?.full_name!==expectedRepo||env.GITHUB_REPOSITORY!==expectedRepo)
  errors.push('Not a native merge_group event from this repository');
 if(!sha(env.GITHUB_SHA)||group?.head_sha!==env.GITHUB_SHA||
  group?.head_ref!==env.GITHUB_REF||
  !/^refs\/heads\/gh-readonly-queue\/develop\/.+/.test(group?.head_ref??'')||
  group?.base_ref!=='refs/heads/develop'||!sha(group?.base_sha))
  errors.push('Queue head/ref/base is missing or mismatched');
 return errors;
}

export function queueFullErrors({event,env,needs,ruleset,run,latest,jobs,checkout,admission},{metadataOnly=false}={}) {
 const errors=queueEventErrors(event,env);
 const statusPolicy=ruleset?.rules?.find(rule=>rule.type==='required_status_checks')?.parameters;
 const checks=statusPolicy?.required_status_checks;
 const pull=ruleset?.rules?.find(rule=>rule.type==='pull_request')?.parameters;
 if(ruleset?.target!=='branch'||ruleset?.enforcement!=='active'||
  JSON.stringify(ruleset?.conditions?.ref_name?.include)!==JSON.stringify(['refs/heads/develop'])||
  JSON.stringify(ruleset?.conditions?.ref_name?.exclude)!=='[]'||
  (Object.hasOwn(ruleset??{},'bypass_actors')?
   !Array.isArray(ruleset.bypass_actors)||ruleset.bypass_actors.length!==0:!queueRulesAttested(ruleset,admission))||
  !ruleset.rules?.some(rule=>rule.type==='merge_queue'&&
   rule.parameters?.merge_method==='SQUASH'&&rule.parameters?.grouping_strategy==='ALLGREEN'))
  errors.push('Native develop Merge Queue protection is not active or has bypass actors');
 if(statusPolicy?.strict_required_status_checks_policy!==true||
  JSON.stringify(pull?.allowed_merge_methods)!==JSON.stringify(['squash'])||
  pull?.required_review_thread_resolution!==true||!ruleset?.rules?.some(rule=>rule.type==='required_linear_history'))
  errors.push('Native queue must preserve Strict, squash-only PRs, resolved threads and linear history');
 for(const context of contexts) {
  const check=checks?.find(c=>c.context===context);
  if(!check||(context==='independent-review'?check.integration_id!=null:check.integration_id!==15368))
   errors.push('Required queue admission/check source missing: '+context);
 }
 if(env.FULL_MODE!=='full'||needs?.impact?.result!=='success'||needs?.rules?.result!=='success'||
  needs?.fast?.result!=='skipped'||needs?.presentation?.result!=='success'||
  needs?.['engineering-posix']?.result!=='success')
  errors.push('All native merge group checks must run in Full mode and succeed');
 if(!id(Number(env.GITHUB_RUN_ID))||!id(Number(env.GITHUB_RUN_ATTEMPT))||
  run?.id!==Number(env.GITHUB_RUN_ID)||run?.run_attempt!==Number(env.GITHUB_RUN_ATTEMPT)||
  run?.event!=='merge_group'||run?.head_sha!==env.GITHUB_SHA||
  run?.path!==qualityWorkflowPath||run?.status!=='in_progress'||
  run?.repository?.full_name!==expectedRepo||
  latest?.id!==run?.id||latest?.run_attempt!==run?.run_attempt)
  errors.push('Superseded or mismatched merge group Quality run');
 const seen=new Set();
 if(!Array.isArray(jobs))errors.push('Missing Full job inventory');
 for(const job of jobs??[]) {
  const key=job.name+':'+job.run_attempt;
  if(!currentFullQualityJobs.includes(job.name)||seen.has(key)||!id(job.id)||
   !id(job.run_attempt)||job.run_attempt>run?.run_attempt||
   job.run_id!==run?.id||job.head_sha!==env.GITHUB_SHA)
   errors.push('Unknown, duplicate, stale or mismatched Full job: '+job.name);
  seen.add(key);
 }
 for(const name of currentFullQualityJobs) {
  const job=(jobs??[]).filter(j=>j.name===name).sort((a,b)=>b.run_attempt-a.run_attempt)[0];
  if(name==='check'){
   if(job?.status!=='in_progress'||job.conclusion!=null||job.run_attempt!==run?.run_attempt)
    errors.push('Full aggregate is not the current running job');
  } else if(job?.status!=='completed'||job.conclusion!==(name==='fast'?'skipped':'success'))
   errors.push('Full job is missing or not successful: '+name);
 }
 const receipt=checkout?.checkout??{};
 if(receipt.schemaVersion!==1||receipt.event!=='merge_group'||receipt.runId!==run?.id||
  receipt.tested!==env.GITHUB_SHA||receipt.head!==env.GITHUB_SHA||
  receipt.base!==event?.merge_group?.base_sha||receipt.prNumber!=null||
  !Array.isArray(receipt.parents)||!receipt.parents.every(sha))
  errors.push('Immutable queue checkout receipt does not match tested group');
 if(!metadataOnly)errors.push(...receiptErrors(receipt,checkout?.checkoutArtifact,jobs,run,3));
 return errors;
}

function gh(...args) {
 const p=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
 if(p.error||p.status!==0)throw Error('Merge Queue GitHub API failed: '+(p.error?.message??p.stderr));
 return p.stdout;
}
function post(query,head,state,context,runId) {
 const result=JSON.parse(query('api','--method','POST',`repos/${expectedRepo}/statuses/${head}`,
  '-f','state='+state,'-f','context='+context,
  '-f','description='+(state==='pending'?'Awaiting verified native merge group Full':'Verified native queue admission and exact Full group'),
  '-f',`target_url=https://github.com/${expectedRepo}/actions/runs/${runId}`));
 if(result.state!==state||result.context!==context)throw Error('Queue status write readback failed: '+context);
}
export function main(env=process.env,query=gh,{pending=false,loadCheckout}={}) {
 const event=JSON.parse(readFileSync(env.GITHUB_EVENT_PATH,'utf8'));
 const identityErrors=queueEventErrors(event,env);
 if(identityErrors.length)throw Error(identityErrors.join('; '));
 const head=env.GITHUB_SHA,runId=Number(env.GITHUB_RUN_ID);
 if(pending){
  for(const context of ['full-quality','independent-review'])post(query,head,'pending',context,runId);
  return {state:'pending'};
 }
 const get=path=>JSON.parse(query('api',`repos/${expectedRepo}/${path}`));
 const pages=(path,key)=>JSON.parse(query('api','--paginate','--slurp',`repos/${expectedRepo}/${path}`)).flatMap(page=>page[key]);
 const run=get('actions/runs/'+runId);
 const latest=pages(`actions/workflows/quality.yml/runs?event=merge_group&head_sha=${head}&per_page=100`,'workflow_runs')
  .filter(r=>r.head_sha===head&&r.event==='merge_group').sort((a,b)=>b.id-a.id)[0];
 const ruleset=get('rulesets/25870651'),jobs=pages(`actions/runs/${runId}/jobs?filter=all&per_page=100`,'jobs');
 const needs=JSON.parse(env.FULL_NEEDS);
 const admission=collectQueueAdmission(event,env,query,ruleset);
 const context={event,env,needs,ruleset,run,latest,jobs,admission};
 // Do not download or publish on an already-invalid run.
 // Validate all metadata first; actual receipt contents are checked below.
 const pre=queueFullErrors({...context,checkout:{checkout:{schemaVersion:1,event:'merge_group',runId,
  tested:head,head,base:event.merge_group.base_sha,parents:[]}}},{metadataOnly:true});
 if(pre.length)throw Error(pre.join('\n'));
 const dir=mkdtempSync(join(tmpdir(),'abyss-queue-'));
 let receipt;
 try{receipt=(loadCheckout??((r,j)=>checkoutReceipt(expectedRepo,r,j,dir,query,3,{allowRunningAggregate:true})))(run,jobs);}
 finally{rmSync(dir,{recursive:true,force:true});}
 const errors=queueFullErrors({...context,checkout:receipt});
 if(errors.length)throw Error(errors.join('\n'));
 const commit=get('commits/'+head);
 if(commit?.sha!==head||!Array.isArray(commit.parents)||!commit.parents.length||
  !commit.parents.every(parent=>sha(parent?.sha))||
  JSON.stringify(receipt.checkout.parents)!==JSON.stringify(commit.parents.map(parent=>parent.sha)))
  throw Error('Actual queue commit parent vector differs from checkout receipt');
 // A rerun could begin during artifact download. Never let an old attempt
 // overwrite the new group's pending/failure status.
 const current=get('actions/runs/'+runId);
 const again=pages(`actions/workflows/quality.yml/runs?event=merge_group&head_sha=${head}&per_page=100`,'workflow_runs')
  .filter(r=>r.head_sha===head&&r.event==='merge_group').sort((a,b)=>b.id-a.id)[0];
 if(current.run_attempt!==run.run_attempt||current.status!=='in_progress'||
  again?.id!==run.id||again.run_attempt!==run.run_attempt)
  throw Error('Queue Full run changed during artifact verification');
 const finalRules=get('rulesets/25870651');
 const finalErrors=queueFullErrors({...context,ruleset:finalRules,checkout:receipt});
 if(finalErrors.length)throw Error(finalErrors.join('\n'));
 if(collectQueueAdmission(event,env,query,finalRules)!==admission)
  throw Error('Native group PR authorization changed during artifact verification');
 for(const name of ['full-quality','independent-review'])post(query,head,'success',name,runId);
 return {state:'success',runId,head};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{console.log(JSON.stringify(main(process.env,gh,{pending:process.argv[2]==='--pending'})));}
 catch(error){console.error(error.message);process.exitCode=1;}
}
