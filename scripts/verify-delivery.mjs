import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const requiredJobs=['check','presentation','engineering-posix'];
export const qualityWorkflowPath='.github/workflows/quality.yml';
// The ordinary PR/push Quality contract. Its matrix is checked against the
// workflow in delivery.test.mjs; local-special is a separate diagnostic path.
export const fullQualityJobs=[...requiredJobs,
  ...Array.from({length:8},(_,i)=>`rules (${i+1}/8)`),
  ...Array.from({length:4},(_,i)=>`engineering-posix (${i+1}/4)`)];
const validSha=value=>/^[a-f0-9]{40}$/.test(value??'');
const positiveId=value=>Number.isSafeInteger(value)&&value>0;
const parentShas=commit=>Array.isArray(commit?.parents)?commit.parents.map(parent=>parent?.sha):undefined;
function qualityErrors(jobs,{attempt,runId,head}) {
  // Collect filter=all, not one attempt: reruns preserve GITHUB_SHA/GITHUB_REF
  // and only reexecute selected jobs. Never search for the last *successful*
  // execution; a newer failure must supersede an older success.
  const errors=[];
  if(!Array.isArray(jobs))return ['Quality jobs are missing'];
  const identities=new Set(),ids=new Set();
  for(const job of jobs) {
    const identity=`${job?.name}:${job?.run_attempt}`;
    if(!fullQualityJobs.includes(job?.name)||!positiveId(job?.id)||ids.has(job.id)||identities.has(identity)||
      !positiveId(job?.run_attempt)||job.run_attempt>attempt||job.run_id!==runId||job.head_sha!==head)
      errors.push(`Unexpected, duplicate or mismatched Quality job ${job?.name}`);
    identities.add(identity);ids.add(job?.id);
  }
  if(!jobs.some(job=>job?.run_attempt===attempt))errors.push('Quality latest attempt has no jobs');
  for(const name of fullQualityJobs) {
    const job=latestJob(jobs,name);
    if(job?.status!=='completed'||job.conclusion!=='success')errors.push(`Quality job ${name} is missing, incomplete or unsuccessful on its latest execution`);
  }
  return errors;
}
function latestJob(jobs,name) {
  return Array.isArray(jobs)?jobs.filter(job=>job?.name===name).sort((a,b)=>b.run_attempt-a.run_attempt)[0]:undefined;
}
function receiptErrors(checkout,artifact,jobs,run) {
  // Only rules (1/8) writes this artifact. Its last successful execution may
  // predate the run's latest attempt; the receipt still binds the exact base,
  // head, tested commit and parents, checked separately below.
  const attempt=latestJob(jobs,'rules (1/8)')?.run_attempt;
  if(checkout?.schemaVersion!==1||!positiveId(attempt)||checkout?.attempt!==attempt||
    !positiveId(artifact?.id)||artifact.name!==`quality-${run?.id}-${attempt}-check`||artifact.expired!==false||
    artifact.workflow_run?.id!==run?.id||artifact.workflow_run?.head_sha!==run?.head_sha)
    return ['Checkout receipt/artifact is missing, expired or differs from the effective rules (1/8) identity'];
  return [];
}
function runErrors(run,{head,event,runId,attempt,branch,repo}) {
  const errors=[];
  if(!run||run.path!==qualityWorkflowPath||run.head_sha!==head||run.event!==event||
    !positiveId(run.id)||!positiveId(run.run_attempt)||run.id!==runId||run.run_attempt!==attempt||
    run.status!=='completed'||run.conclusion!=='success'||run.repository?.full_name!==repo||branch!==undefined&&run.head_branch!==branch)errors.push('Exact current-attempt Quality run is missing, incomplete, unsuccessful or mismatched');
  return errors;
}
export function verifyDelivery(e) {
  if(!e||typeof e!=='object')return ['Missing preflight evidence'];
  const errors=[];
  if(e.schemaVersion!==2||!/^[-\w.]+\/[-\w.]+$/.test(e.repo??'')||!['develop','master'].includes(e.baseRef))errors.push('Missing versioned repository/target evidence');
  for(const field of ['head','base','tested','sourceTree'])if(!validSha(e[field]))errors.push(`Invalid ${field}`);
  if(e.event!=='pull_request'||!positiveId(e.runId)||!positiveId(e.attempt)||!positiveId(e.prNumber))errors.push('Expected PR run identity');
  for(const field of ['head','base','tested','runId','event','prNumber'])if(e.checkout?.[field]!==e[field])errors.push(`Checkout ${field} is stale or mismatched`);
  errors.push(...receiptErrors(e.checkout,e.checkoutArtifact,e.jobs,e.run));
  if(JSON.stringify(e.parents)!==JSON.stringify([e.base,e.head]))errors.push('Tested merge parents do not match current base/head');
  if(e.testedCommit?.sha!==e.tested||JSON.stringify(parentShas(e.testedCommit))!==JSON.stringify(e.parents)||e.testedCommit?.commit?.tree?.sha!==e.sourceTree)errors.push('Tested source commit/tree evidence is missing or mismatched');
  if(JSON.stringify(e.checkout?.parents)!==JSON.stringify(e.parents))errors.push('Checkout merge parents differ from tested commit');
  if(!Array.isArray(e.run?.pull_requests)||!e.run.pull_requests.some(pr=>pr?.number===e.prNumber))errors.push('Quality run does not belong to this PR');
  errors.push(...runErrors(e.run,{head:e.head,event:e.event,runId:e.runId,attempt:e.attempt,repo:e.repo}),...qualityErrors(e.jobs,{attempt:e.attempt,runId:e.runId,head:e.head}));
  errors.push(...runErrors(e.currentRun,{head:e.head,event:e.event,runId:e.runId,attempt:e.attempt,repo:e.repo}));
  if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base||!e.review?.reviewId||e.review?.conclusion!=='pass'||!Array.isArray(e.review?.unresolved)||e.review.unresolved.length)errors.push('Review is missing, stale, or has unresolved findings');
  return errors;
}
export function verifyMergedDelivery(e) {
  if(!e||typeof e!=='object')return {state:'merged_pending',errors:['Missing merged evidence']};
  const preflight=e.preflight??{},errors=verifyDelivery(preflight).map(error=>`Preflight: ${error}`);
  if(e.schemaVersion!==2)errors.push('Missing versioned merged evidence');
  if(e.repo!==preflight.repo)errors.push('Merged evidence repository differs from preflight');
  if(e.pr?.number!==preflight.prNumber||!e.pr?.merged||e.pr?.state!=='closed')errors.push('Expected the verified PR to be merged');
  if(e.pr?.head?.sha!==preflight.head||e.pr?.base?.ref!==preflight.baseRef)errors.push('Merged PR head/target differs from preflight');
  if(!validSha(e.commit?.sha)||e.commit?.sha!==e.pr?.merge_commit_sha)errors.push('Actual merged commit does not match merge_commit_sha');
  if(JSON.stringify(parentShas(e.commit))!==JSON.stringify([preflight.base]))errors.push('Actual squash parent differs from verified base; obtain fresh evidence for the new combination');
  if(!validSha(e.commit?.commit?.tree?.sha)||e.commit?.commit?.tree?.sha!==preflight.sourceTree)errors.push('Actual merged source tree differs from the verified source tree');
  if(e.current?.number!==e.pr?.number||e.current?.head?.sha!==e.pr?.head?.sha||e.current?.base?.ref!==e.pr?.base?.ref||!e.current?.merged||e.current?.state!=='closed'||e.current?.merge_commit_sha!==e.pr?.merge_commit_sha)errors.push('Merged PR identity changed during verification');
  errors.push(...runErrors(e.run,{head:e.commit?.sha,event:'push',runId:e.run?.id,attempt:e.run?.run_attempt,branch:preflight.baseRef,repo:e.repo}));
  errors.push(...runErrors(e.currentRun,{head:e.commit?.sha,event:'push',runId:e.run?.id,attempt:e.run?.run_attempt,branch:preflight.baseRef,repo:e.repo}));
  errors.push(...qualityErrors(e.jobs,{attempt:e.run?.run_attempt,runId:e.run?.id,head:e.commit?.sha}));
  errors.push(...receiptErrors(e.checkout,e.checkoutArtifact,e.jobs,e.run));
  for(const [field,value] of Object.entries({event:'push',runId:e.run?.id,tested:e.commit?.sha,head:e.commit?.sha,base:preflight.base})) {
    if(value===undefined||e.checkout?.[field]!==value)errors.push(`Merged checkout ${field} is missing, stale or mismatched`);
  }
  if(e.checkout?.prNumber!==undefined||JSON.stringify(e.checkout?.parents)!==JSON.stringify([preflight.base]))errors.push('Merged checkout is not the actual squash commit');
  return {state:errors.length?'merged_pending':'merged_passed',errors};
}
function gh(...args) {
  const result=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
  if(result.error||result.status!==0)throw new Error(`GitHub query failed: ${result.error?.message||result.stderr}`);return result.stdout;
}
function pages(query,endpoint,key) {
  const result=JSON.parse(query('api','--paginate','--slurp',endpoint));
  if(!Array.isArray(result)||result.some(page=>!Array.isArray(page[key])))throw new Error(`Malformed paginated ${key} response`);
  return result.flatMap(page=>page[key]);
}
export function checkoutReceipt(repo,run,jobs,dir,query=gh) {
  const errors=qualityErrors(jobs,{attempt:run.run_attempt,runId:run.id,head:run.head_sha});
  if(errors.length)throw new Error(errors.join('\n'));
  const attempt=latestJob(jobs,'rules (1/8)').run_attempt,name=`quality-${run.id}-${attempt}-check`;
  const artifacts=pages(query,`repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`,'artifacts').filter(a=>a?.name===name);
  const artifact=artifacts[0];
  if(artifacts.length!==1||receiptErrors({schemaVersion:1,attempt},artifact,jobs,run).length)throw new Error('Missing, duplicate, expired or mismatched checkout artifact');
  query('run','download',String(run.id),'--repo',repo,'--name',name,'--dir',dir);
  // Artifacts are immutable. Recheck the ID after name-based gh download so a
  // concurrent deletion/replacement cannot change the object we just accepted.
  const current=JSON.parse(query('api',`repos/${repo}/actions/artifacts/${artifact.id}`));
  if(current.id!==artifact.id||current.name!==name||receiptErrors({schemaVersion:1,attempt},current,jobs,run).length)throw new Error('Checkout artifact changed during download');
  return {checkout:JSON.parse(readFileSync(join(dir,'ci-checkout.json'),'utf8')),checkoutArtifact:artifact};
}
function latestQualityRun(query,repo,{event,head,branch,number}) {
  const runs=pages(query,`repos/${repo}/actions/workflows/quality.yml/runs?event=${event}&head_sha=${head}&per_page=100`,'workflow_runs');
  return runs.filter(run=>run.head_sha===head&&run.event===event&&
    (branch===undefined||run.head_branch===branch)&&
    (number===undefined||Array.isArray(run.pull_requests)&&run.pull_requests.some(pr=>pr.number===number)))
    .sort((a,b)=>b.id-a.id)[0];
}
export function collectMergedDelivery(repo,number,preflight,query=gh,loadCheckout=(run,jobs)=>{
  const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
  return checkoutReceipt(repo,run,jobs,dir,query);
}) {
  const pr=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  if(!pr.merged||!validSha(pr.merge_commit_sha))throw new Error('PR is not merged; its passing preflight is only pr_passed');
  const commit=JSON.parse(query('api',`repos/${repo}/commits/${pr.merge_commit_sha}`));
  const identity={event:'push',head:pr.merge_commit_sha,branch:pr.base.ref};
  const run=latestQualityRun(query,repo,identity);
  const jobs=run?.status==='completed'?pages(query,`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`,'jobs'):[];
  const receipt=run?.status==='completed'&&run.conclusion==='success'?loadCheckout(run,jobs):{};
  const current=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  const currentRun=latestQualityRun(query,repo,identity);
  return {schemaVersion:2,repo,preflight,pr,commit,run,jobs,...receipt,current,currentRun};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [number,evidenceFile,mode,...extra]=process.argv.slice(2);
    if(!/^[1-9]\d*$/.test(number??'')||!evidenceFile||mode!==undefined&&mode!=='--merged'||extra.length)throw new Error('Usage: npm run verify:delivery -- <PR-number> <independent-review.json> OR <PR-number> <preflight-evidence.json> --merged');
    const repo=gh('repo','view','--json','nameWithOwner','--jq','.nameWithOwner').trim();
    const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
    if(mode==='--merged') {
      const preflight=JSON.parse(readFileSync(evidenceFile,'utf8'));
      if(preflight.repo!==repo||preflight.prNumber!==Number(number)||verifyDelivery(preflight).length)throw new Error('Preflight evidence is invalid, stale or belongs to a different PR/repository');
      const evidence=collectMergedDelivery(repo,Number(number),preflight,gh,(run,jobs)=>checkoutReceipt(repo,run,jobs,dir));
      const result=verifyMergedDelivery(evidence);
      writeFileSync(join(dir,'evidence.json'),JSON.stringify({...evidence,...result},null,2)+'\n');
      console.log(`Delivery state: ${result.state}; actual merged commit ${evidence.pr.merge_commit_sha}; evidence ${dir}`);
      if(result.errors.length)throw new Error(result.errors.join('\n'));
      process.exitCode=0;
    } else {
      const pr=JSON.parse(gh('api',`repos/${repo}/pulls/${number}`));
      if(pr.state!=='open'||pr.merged)throw new Error('Preflight requires an open PR; use --merged with its saved preflight evidence after merge');
      const identity={event:'pull_request',head:pr.head.sha,number:Number(number)};
      const run=latestQualityRun(gh,repo,identity);
      if(!run||run.status!=='completed'||run.conclusion!=='success')throw new Error('Current Quality run is missing or not successful');
      const jobs=pages(gh,`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`,'jobs');
      const {checkout,checkoutArtifact}=checkoutReceipt(repo,run,jobs,dir);
      if(checkout.tested!==pr.merge_commit_sha)throw new Error('CI did not test the current PR merge combination');
      const commit=JSON.parse(gh('api',`repos/${repo}/commits/${checkout.tested}`));
      const evidence={schemaVersion:2,repo,baseRef:pr.base.ref,sourceTree:commit.commit.tree.sha,testedCommit:commit,
        head:pr.head.sha,base:pr.base.sha,tested:checkout.tested,parents:commit.parents.map(p=>p.sha),
        runId:run.id,attempt:run.run_attempt,event:run.event,prNumber:Number(number),run,jobs,checkout,checkoutArtifact,
        review:JSON.parse(readFileSync(evidenceFile,'utf8'))};
      const current=JSON.parse(gh('api',`repos/${repo}/pulls/${number}`));
      evidence.currentRun=latestQualityRun(gh,repo,identity);
      const errors=verifyDelivery(evidence);
      if(current.state!=='open'||current.merged||current.head.sha!==evidence.head||current.base.sha!==evidence.base||current.base.ref!==evidence.baseRef||current.merge_commit_sha!==evidence.tested)errors.push('PR head/base/merge combination changed during verification');
      writeFileSync(join(dir,'evidence.json'),JSON.stringify({...evidence,state:errors.length?'pr_pending':'pr_passed',errors},null,2)+'\n');
      if(errors.length)throw new Error(errors.join('\n'));
      console.log(`Delivery state: pr_passed; evidence ${dir}; merge with --match-head-commit ${evidence.head}. Then run verify:delivery -- ${number} ${join(dir,'evidence.json')} --merged. Review provenance must still be independently inspected.`);
    }
  }catch(error){console.error(error.message);process.exitCode=1;}
}
