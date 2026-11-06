import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const workflowPath='.github/workflows/quality.yml';
const sha=value=>typeof value==='string'&&/^[a-f0-9]{40}$/.test(value);
const positive=value=>Number.isSafeInteger(value)&&value>0;
const skippedJobs=new Set(['rules','engineering-posix-shards']);
export const currentFastQualityJobs=Object.freeze([
 'check','presentation','engineering-posix','impact',
 'fast (ubuntu-24.04)','fast (windows-2025)',...skippedJobs,
]);

// Fast has a separate inventory. A Full-shaped green or a single successful
// platform is never a substitute for the two complete affected executions.
export function fastQualityJobErrors(jobs,{attempt,runId,head,allowRunningAggregate=false}) {
 const errors=[],ids=new Set(),identities=new Set();
 if(!Array.isArray(jobs))return ['Missing actual Fast Quality jobs'];
 for(const job of jobs) {
  const key=job?.name+':'+job?.run_attempt;
  if(!currentFastQualityJobs.includes(job?.name)||!positive(job?.id)||ids.has(job.id)||
   identities.has(key)||job?.run_id!==runId||job?.head_sha!==head||
   !positive(job?.run_attempt)||job.run_attempt>attempt)
   errors.push('Invalid Fast job identity: '+job?.name);
  ids.add(job?.id);identities.add(key);
 }
 for(const name of currentFastQualityJobs) {
  const job=jobs.filter(j=>j?.name===name).sort((a,b)=>b.run_attempt-a.run_attempt)[0];
  if(job?.run_attempt!==attempt)errors.push('Fast job is missing from the current attempt: '+name);
  const running=allowRunningAggregate&&name==='check'&&job?.status==='in_progress'&&job.conclusion==null;
  if(!running&&(job?.status!=='completed'||job.conclusion!==(skippedJobs.has(name)?'skipped':'success')))
   errors.push('Incomplete or unsuccessful Fast job: '+name);
 }
 return errors;
}

function artifactErrors(artifact,run) {
 if(!positive(artifact?.id)||artifact?.name!==`quality-${run?.id}-${run?.run_attempt}-fast`||
  artifact.expired!==false||artifact.workflow_run?.id!==run?.id||
  artifact.workflow_run?.head_sha!==run?.head_sha)
  return ['Fast checkout artifact is missing, expired or from a different run/attempt'];
 return [];
}
const paths=(values,pattern)=>Array.isArray(values)&&new Set(values).size===values.length&&
 values.every(value=>typeof value==='string'&&pattern.test(value)&&!value.includes('\\')&&
  !value.split('/').some(part=>part==='.'||part==='..'||part===''));

// The successful impact job computes this plan from the exact checked-out
// source; both successful Fast jobs execute that complete immutable plan.
// Bind it to the same checkout artifact instead of accepting a green summary
// with an arbitrary locally supplied selection. Full remains mandatory in queue.
export function prFastErrors(e,{allowRunningAggregate=false,metadataOnly=false}={}) {
 if(!e||typeof e!=='object')return ['Missing Fast PR evidence'];
 const errors=[],run=e.run;
 const running=allowRunningAggregate&&run?.status==='in_progress'&&run.conclusion==null;
 if(typeof e.repo!=='string'||!/^[-\w.]+\/[-\w.]+$/.test(e.repo)||
  !positive(e.runId)||!positive(e.attempt)||run?.id!==e.runId||run?.run_attempt!==e.attempt||
  run?.head_sha!==e.head||run?.event!=='pull_request'||run?.path!==workflowPath||
  run?.repository?.full_name!==e.repo||!Array.isArray(run?.pull_requests)||
  !run.pull_requests.some(p=>p?.number===e.number)||
  !running&&(run?.status!=='completed'||run?.conclusion!=='success')||
  e.latestRun?.id!==e.runId||e.latestRun?.run_attempt!==e.attempt)
  errors.push('Stale or invalid Fast run/attempt');
 const pr=e.pr;
 if(!sha(e.head)||!sha(e.base)||!sha(e.tested)||!positive(e.number)||
  pr?.number!==e.number||pr?.state!=='open'||pr.merged!==false||pr.draft!==false||
  pr.head?.sha!==e.head||pr.head.repo?.full_name!==e.repo||
  pr.base?.ref!=='develop'||pr.base.sha!==e.base||e.target!==e.base||
  pr.merge_commit_sha!==e.tested||e.commit?.sha!==e.tested||
  JSON.stringify(e.commit?.parents?.map(p=>p?.sha))!==JSON.stringify([e.base,e.head]))
  errors.push('Fast tested merge differs from current ready PR HEAD/BASE');
 if(!Array.isArray(pr?.labels)||pr.labels.some(label=>{
  const name=typeof label==='string'?label:label?.name;
  return typeof name!=='string'||name==='ci:full';
 }))
  errors.push('Fast cannot authorize an explicit Full request or unknown labels');
 errors.push(...fastQualityJobErrors(e.jobs,{attempt:e.attempt,runId:e.runId,head:e.head,allowRunningAggregate}));
 if(metadataOnly)return errors;
 errors.push(...artifactErrors(e.checkoutArtifact,run));
 const c=e.checkout;
 if(c?.schemaVersion!==1||c.attempt!==e.attempt)errors.push('Fast checkout has a missing or different execution attempt');
 for(const [key,value] of Object.entries({runId:e.runId,head:e.head,base:e.base,tested:e.tested,prNumber:e.number,event:'pull_request'}))
  if(c?.[key]!==value)errors.push('Actual Fast checkout differs from PR source: '+key);
 if(JSON.stringify(c?.parents)!==JSON.stringify([e.base,e.head]))errors.push('Fast checkout merge parent order differs');
 const p=e.plan;
 if(p?.mode!=='fast'||p.sha!==e.tested||p.head!==e.head||p.base!==e.base||
  p.runId!==e.runId||p.attempt!==e.attempt||typeof p.reason!=='string'||!p.reason.trim()||
  !paths(p.changed,/^[^/].*$/)||!p.changed.length||
  !paths(p.js,/^tests\/[^/]+\.test\.mjs$/)||!paths(p.lua,/^tests\/lua\/[^/]+\.lua$/))
  errors.push('Missing, malformed or mismatched complete Fast impact plan');
 else if(!p.js.length&&!p.lua.length&&!p.changed.every(path=>/^docs\/(?:HANDOFF|CI|CI-FAST)\.md$/.test(path)))
  errors.push('Zero tests only qualify for the explicit prose allowlist');
 if(e.receiptError)errors.push('Fast checkout collection failed: '+e.receiptError);
 return errors;
}

export function collectFastCheckout(repo,run,jobs,dir,query,{allowRunningAggregate=false}={}) {
 const errors=fastQualityJobErrors(jobs,{attempt:run?.run_attempt,runId:run?.id,head:run?.head_sha,allowRunningAggregate});
 if(errors.length)throw Error(errors.join('\n'));
 const pages=JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`));
 if(!Array.isArray(pages)||!pages.length||pages.some(page=>!Array.isArray(page?.artifacts)))
  throw Error('Cannot read the complete Fast artifact inventory');
 const name=`quality-${run.id}-${run.run_attempt}-fast`;
 const matches=pages.flatMap(page=>page.artifacts).filter(a=>a?.name===name),artifact=matches[0];
 if(matches.length!==1||artifactErrors(artifact,run).length)throw Error('Missing, duplicate, expired or mismatched Fast artifact');
 query('run','download',String(run.id),'--repo',repo,'--name',name,'--dir',dir);
 const current=JSON.parse(query('api',`repos/${repo}/actions/artifacts/${artifact.id}`));
 if(current?.id!==artifact.id||artifactErrors(current,run).length)throw Error('Fast artifact changed during download');
 return {checkout:JSON.parse(readFileSync(join(dir,'ci-checkout.json'),'utf8')),
  plan:JSON.parse(readFileSync(join(dir,'ci-impact.json'),'utf8')),checkoutArtifact:artifact};
}
