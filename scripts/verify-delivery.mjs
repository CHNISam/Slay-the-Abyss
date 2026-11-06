import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import {qualityShardJobs} from './ci-quality-shape.mjs';
import {projectRepositoryId,currentProjectRepository,projectRepositoryMatches,collectIdentityWitness,identityWitnessValid} from './repository-identity.mjs';
import {prFastErrors,collectFastCheckout} from './pr-quality-evidence.mjs';

export const requiredJobs=['check','presentation','engineering-posix'];
export const qualityWorkflowPath='.github/workflows/quality.yml';
// The ordinary PR/push Quality contract. Its matrix is checked against the
// workflow in delivery.test.mjs; local-special is a separate diagnostic path.
export const fullQualityJobs=[...requiredJobs,
  ...Array.from({length:8},(_,i)=>`rules (${i+1}/8)`),
  ...Array.from({length:4},(_,i)=>`engineering-posix (${i+1}/4)`)];
export const deliverySchemaVersion=3;
export const currentFullQualityJobs=[...requiredJobs,...qualityShardJobs,'impact','fast'];
const validSha=value=>/^[a-f0-9]{40}$/.test(value??'');
const positiveId=value=>Number.isSafeInteger(value)&&value>0;
const parentShas=commit=>Array.isArray(commit?.parents)?commit.parents.map(parent=>parent?.sha):undefined;
// Deliberately narrow: only non-executable narrative documents qualify.
const lowRiskDocPath=/^(?:README\.md|CHANGELOG\.md|docs\/(?:drafts|history|lore|research)\/.+\.(?:md|txt))$/;
export function isLowRiskDocumentationChange(files,count) {
  return Number.isSafeInteger(count)&&count>0&&count<=20&&Array.isArray(files)&&files.length===count&&
    new Set(files.map(file=>file?.filename)).size===count&&files.every(file=>
      file&&typeof file.filename==='string'&&lowRiskDocPath.test(file.filename)&&
      !/^(?:AGENTS(?:\.override)?|CLAUDE(?:\.local)?|SKILL)\.md$/i.test(file.filename.split('/').at(-1))&&
      !file.filename.includes('\\')&&!file.filename.split('/').some(segment=>segment==='.'||segment==='..')&&
      ['added','modified'].includes(file.status)&&validSha(file.sha));
}
function qualityErrors(jobs,{attempt,runId,head,schemaVersion,allowRunningAggregate=false}) {
  // Collect filter=all, not one attempt: reruns preserve GITHUB_SHA/GITHUB_REF
  // and only reexecute selected jobs. Never search for the last *successful*
  // execution; a newer failure must supersede an older success.
  const errors=[];
  // Version 2 remains the frozen, pre-routing fifteen-job contract. Never
  // infer a legacy contract from missing jobs in newly collected evidence.
  const expectedJobs=schemaVersion===2?fullQualityJobs:schemaVersion===3?currentFullQualityJobs:undefined;
  if(!expectedJobs)return ['Unknown Quality evidence schema version'];
  if(!Array.isArray(jobs))return ['Quality jobs are missing'];
  const identities=new Set(),ids=new Set();
  for(const job of jobs) {
    const identity=`${job?.name}:${job?.run_attempt}`;
    if(!expectedJobs.includes(job?.name)||!positiveId(job?.id)||ids.has(job.id)||identities.has(identity)||
      !positiveId(job?.run_attempt)||job.run_attempt>attempt||job.run_id!==runId||job.head_sha!==head)
      errors.push(`Unexpected, duplicate or mismatched Quality job ${job?.name}`);
    identities.add(identity);ids.add(job?.id);
  }
  if(!jobs.some(job=>job?.run_attempt===attempt))errors.push('Quality latest attempt has no jobs');
  for(const name of expectedJobs) {
    const job=latestJob(jobs,name);
    // A false job-level condition skips `fast` before matrix expansion. Fast
    // coverage (including expanded matrix jobs) can never certify Full.
    const conclusion=name==='fast'?'skipped':'success';
    const runningAggregate=allowRunningAggregate&&name==='check'&&job?.status==='in_progress'&&job.conclusion==null&&job.run_attempt===attempt;
    if(!runningAggregate&&(job?.status!=='completed'||job.conclusion!==conclusion))errors.push(`Quality job ${name} is missing, incomplete or does not have required conclusion ${conclusion} on its latest execution`);
  }
  return errors;
}
function latestJob(jobs,name) {
  return Array.isArray(jobs)?jobs.filter(job=>job?.name===name).sort((a,b)=>b.run_attempt-a.run_attempt)[0]:undefined;
}
const firstRulesJob=schemaVersion=>schemaVersion===2?'rules (1/8)':qualityShardJobs[0];
function executionTime(value) {
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value))return NaN;
  const time=Date.parse(value);
  return Number.isFinite(time)&&new Date(time).toISOString()===value.replace('Z','.000Z')?time:NaN;
}
function executionFingerprint(job) {
  const start=executionTime(job?.started_at),end=executionTime(job?.completed_at);
  if(job?.status!=='completed'||job.conclusion!=='success'||!Number.isFinite(start)||!Number.isFinite(end)||start>end||
    !positiveId(job.runner_id)||typeof job.runner_name!=='string'||!job.runner_name.trim()||
    !Array.isArray(job.labels)||!job.labels.length||job.labels.some(label=>typeof label!=='string'||!label)||
    !Array.isArray(job.steps)||!job.steps.length)return undefined;
  let previous=0;const steps=[];
  for(const step of job.steps) {
    const a=executionTime(step?.started_at),b=executionTime(step?.completed_at);
    if(!positiveId(step?.number)||step.number<=previous||typeof step.name!=='string'||!step.name.trim()||
      step.status!=='completed'||!['success','skipped'].includes(step.conclusion)||
      !Number.isFinite(a)||!Number.isFinite(b)||a<start||a>b||b>end)return undefined;
    previous=step.number;
    steps.push([step.number,step.name,step.status,step.conclusion,step.started_at,step.completed_at]);
  }
  return JSON.stringify([job.started_at,job.completed_at,job.runner_id,job.runner_name,job.labels,steps]);
}
function receiptExecutionAttempt(jobs,schemaVersion) {
  let job=latestJob(jobs,firstRulesJob(schemaVersion));
  if(!positiveId(job?.run_attempt))return undefined;
  // Ordinary and historical sparse evidence keeps its declared attempt. Only
  // a record created after execution finished can justify inherited evidence.
  if(!(executionTime(job.created_at)>executionTime(job.completed_at)))return job.run_attempt;
  while(job) {
    const fingerprint=executionFingerprint(job),created=executionTime(job.created_at);
    if(!fingerprint||!Number.isFinite(created)||!positiveId(job.id)||!positiveId(job.run_id)||!validSha(job.head_sha))return undefined;
    if(created<=executionTime(job.started_at))return job.run_attempt;
    if(created<=executionTime(job.completed_at))return undefined;
    // Do not search past a different/failed execution or missing attempt. New
    // record IDs and runner_group_id may differ, but execution must not.
    const prior=jobs.filter(candidate=>candidate?.name===job.name&&candidate.run_attempt===job.run_attempt-1);
    if(prior.length!==1||prior[0].id===job.id||prior[0].run_id!==job.run_id||prior[0].head_sha!==job.head_sha||
      !(executionTime(prior[0].created_at)<created)||executionFingerprint(prior[0])!==fingerprint)return undefined;
    job=prior[0];
  }
  return undefined;
}
// Shared artifact/attempt association only. Callers separately validate all
// jobs, run identity and the checkout's exact SHA/parent identity.
export function receiptErrors(checkout,artifact,jobs,run,schemaVersion) {
  // Only the shape's first rules shard writes this artifact. Its execution may
  // predate the run's latest attempt; the receipt still binds the exact base,
  // head, tested commit and parents, checked separately below.
  const jobName=firstRulesJob(schemaVersion),attempt=receiptExecutionAttempt(jobs,schemaVersion);
  if(checkout?.schemaVersion!==1||!positiveId(attempt)||checkout?.attempt!==attempt||
    !positiveId(artifact?.id)||artifact.name!==`quality-${run?.id}-${attempt}-check`||artifact.expired!==false||
    artifact.workflow_run?.id!==run?.id||artifact.workflow_run?.head_sha!==run?.head_sha)
    return [`Checkout receipt/artifact is missing, expired or differs from the effective ${jobName} identity`];
  return [];
}
function runErrors(run,{head,event,runId,attempt,branch,repo}) {
  const errors=[];
  if(!run||run.path!==qualityWorkflowPath||run.head_sha!==head||run.event!==event||
    !positiveId(run.id)||!positiveId(run.run_attempt)||run.id!==runId||run.run_attempt!==attempt||
    run.status!=='completed'||run.conclusion!=='success'||run.repository?.full_name!==repo||branch!==undefined&&run.head_branch!==branch)errors.push('Exact current-attempt Quality run is missing, incomplete, unsuccessful or mismatched');
  return errors;
}
// Auto-merge authorization includes exact Full preflight evidence. It remains
// distinct from merged delivery, which also verifies the actual squash and push CI.
export function verifyAutoMergeArm(e) {
  if(!e||typeof e!=='object')return ['Missing auto-merge arm evidence'];
  const errors=[];
  if(e.repositoryId!==undefined&&e.repositoryId!==projectRepositoryId)errors.push('Auto-merge repository ID differs from the project');
  const fast=e.schemaVersion===6;
  if(fast){
    if(e.kind!=='auto-merge-arm-fast'||!/^[a-f0-9]{64}$/.test(e.queueRulesFingerprint??''))
      errors.push('Fast authorization requires a native queue rules fingerprint');
    if(e.fastPreflight?.schemaVersion!==7)errors.push('Missing exact Fast preflight');
    else{
      errors.push(...verifyDelivery(e.fastPreflight).map(error=>'Fast preflight: '+error));
      for(const field of ['repo','prNumber','head','base','tested','sourceTree'])
        if(e.fastPreflight[field]!==e[field])errors.push('Fast preflight differs from authorization '+field);
      if(JSON.stringify(e.fastPreflight.review)!==JSON.stringify(e.review))errors.push('Fast review differs from authorization');
    }
  }else if(e.fullPreflight===undefined){
    if(!positiveId(e.pendingRun?.id)||!positiveId(e.pendingRun?.attempt)||e.pendingRun.head!==e.head)
      errors.push('Auto-merge requires the exact pending Full run identity');
  }else if(e.fullPreflight.schemaVersion!==3)errors.push('Auto-merge requires current Full preflight evidence');
  else {
    errors.push(...verifyDelivery(e.fullPreflight).map(error=>'Full preflight: '+error));
    for(const field of ['repo','prNumber','head','base','tested','sourceTree'])
      if(e.fullPreflight[field]!==e[field])errors.push('Full preflight differs from auto-merge '+field);
    if(JSON.stringify(e.fullPreflight.review)!==JSON.stringify(e.review))errors.push('Full preflight review differs from authorization');
  }
  if(![4,6].includes(e.schemaVersion)||e.kind!==(fast?'auto-merge-arm-fast':'auto-merge-arm')||!/^[-\w.]+\/[-\w.]+$/.test(e.repo??'')||
    e.baseRef!=='develop'||!positiveId(e.prNumber))errors.push('Missing auto-merge arm identity');
  for(const key of ['head','base','tested','sourceTree','targetBeforeSha','targetAfterSha'])
    if(!validSha(e[key]))errors.push('Missing or invalid auto-merge '+key);
  if(e.targetBeforeSha!==e.base||e.targetAfterSha!==e.base)
    errors.push('Auto-merge target moved during review authorization');
  if(JSON.stringify(e.parents)!==JSON.stringify([e.base,e.head]))
    errors.push('Auto-merge proposed merge parents differ from reviewed HEAD/BASE');
  if(e.review?.disposition==='low-risk-docs') {
    if(!isLowRiskDocumentationChange(e.changedFiles,e.changedFileCount))
      errors.push('Auto-merge documentation waiver is outside the allowed scope');
  } else if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base||
    typeof e.review?.reviewId!=='string'||!e.review.reviewId.trim()||
    e.review.conclusion!=='pass'||!Array.isArray(e.review.unresolved)||e.review.unresolved.length)
    errors.push('Auto-merge independent review is missing, stale or unresolved');
  if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base)
    errors.push('Auto-merge review does not match exact HEAD/BASE');
  if(e.review?.repo!=null&&e.review.repo!==e.repo||
    e.review?.prNumber!=null&&e.review.prNumber!==e.prNumber)
    errors.push('Auto-merge review is for another PR');
  return errors;
}
export function verifyDelivery(e) {
  if(e?.schemaVersion===6)return verifyAutoMergeArm(e);
  if(e?.schemaVersion===7){
    const errors=prFastErrors(e);
    errors.push(...runErrors(e.currentRun,{head:e.head,event:'pull_request',runId:e.runId,attempt:e.attempt,repo:e.repo}));
    if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base||!e.review?.reviewId||
      typeof e.review.reviewId!=='string'||!e.review.reviewId.trim()||
      e.review.conclusion!=='pass'||!Array.isArray(e.review.unresolved)||e.review.unresolved.length)
      errors.push('Fast independent review is missing, stale or unresolved');
    if(e.review?.repo!=null&&e.review.repo!==e.repo||e.review?.prNumber!=null&&e.review.prNumber!==e.prNumber)
      errors.push('Fast review belongs to a different repository/PR');
    if(e.kind!=='pr-fast'||e.event!=='pull_request'||e.baseRef!=='develop'||e.prNumber!==e.number||e.targetBeforeSha!==e.base||e.targetAfterSha!==e.base||
      e.testedCommit?.sha!==e.tested||e.testedCommit?.commit?.tree?.sha!==e.sourceTree||
      !validSha(e.sourceTree)||JSON.stringify(parentShas(e.testedCommit))!==JSON.stringify([e.base,e.head]))
      errors.push('Fast source tree or observed target differs');
    return errors;
  }
  if(!e||typeof e!=='object')return ['Missing preflight evidence'];
  if(e.schemaVersion===4)return [...verifyAutoMergeArm(e),
    ...(e.fullPreflight===undefined?['Review authorization is not successful Full preflight evidence']:[])];
  const errors=[];
  if(![2,3].includes(e.schemaVersion)||!/^[-\w.]+\/[-\w.]+$/.test(e.repo??'')||!['develop','master'].includes(e.baseRef))errors.push('Missing versioned repository/target evidence');
  for(const field of ['head','base','tested','sourceTree'])if(!validSha(e[field]))errors.push(`Invalid ${field}`);
  if(e.schemaVersion===3)for(const field of ['targetBeforeSha','targetAfterSha'])
    if(!validSha(e[field])||e[field]!==e.base)errors.push(`Actual target ${field} is missing, malformed or differs from the verified base`);
  if(e.event!=='pull_request'||!positiveId(e.runId)||!positiveId(e.attempt)||!positiveId(e.prNumber))errors.push('Expected PR run identity');
  for(const field of ['head','base','tested','runId','event','prNumber'])if(e.checkout?.[field]!==e[field])errors.push(`Checkout ${field} is stale or mismatched`);
  errors.push(...receiptErrors(e.checkout,e.checkoutArtifact,e.jobs,e.run,e.schemaVersion));
  if(JSON.stringify(e.parents)!==JSON.stringify([e.base,e.head]))errors.push('Tested merge parents do not match current base/head');
  if(e.testedCommit?.sha!==e.tested||JSON.stringify(parentShas(e.testedCommit))!==JSON.stringify(e.parents)||e.testedCommit?.commit?.tree?.sha!==e.sourceTree)errors.push('Tested source commit/tree evidence is missing or mismatched');
  if(JSON.stringify(e.checkout?.parents)!==JSON.stringify(e.parents))errors.push('Checkout merge parents differ from tested commit');
  if(!Array.isArray(e.run?.pull_requests)||!e.run.pull_requests.some(pr=>pr?.number===e.prNumber))errors.push('Quality run does not belong to this PR');
  errors.push(...runErrors(e.run,{head:e.head,event:e.event,runId:e.runId,attempt:e.attempt,repo:e.repo}),...qualityErrors(e.jobs,{attempt:e.attempt,runId:e.runId,head:e.head,schemaVersion:e.schemaVersion}));
  errors.push(...runErrors(e.currentRun,{head:e.head,event:e.event,runId:e.runId,attempt:e.attempt,repo:e.repo}));
  if(e.review?.disposition==='low-risk-docs') {
    if(e.schemaVersion!==deliverySchemaVersion||e.baseRef!=='develop'||e.review.reviewedHeadSha!==e.head||
      e.review.reviewedBaseSha!==e.base||!isLowRiskDocumentationChange(e.changedFiles,e.changedFileCount))
      errors.push('Low-risk documentation waiver is stale, unverified or out of scope');
  } else if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base||!e.review?.reviewId||e.review?.conclusion!=='pass'||!Array.isArray(e.review?.unresolved)||e.review.unresolved.length)
    errors.push('Review is missing, stale, or has unresolved findings');
  return errors;
}
export function verifyMergedDelivery(e) {
  if(!e||typeof e!=='object')return {state:'merged_pending',errors:['Missing merged evidence']};
  const preflight=e.preflight??{},early=preflight.schemaVersion===4&&preflight.fullPreflight===undefined;
  const errors=(early?verifyAutoMergeArm(preflight):verifyDelivery(preflight)).map(error=>`Preflight: ${error}`);
  const transferred=identityWitnessValid(e.identityWitness,preflight,e.repo);
  if(e.identityWitness!==undefined&&!transferred)errors.push('Repository transfer witness is invalid or changed');
  if(transferred){
    const repositories=[e.pr?.head?.repo,e.pr?.base?.repo,e.current?.head?.repo,e.current?.base?.repo,
      e.run?.repository,e.currentRun?.repository,...(early?[e.prFull?.run?.repository,e.prFull?.currentRun?.repository]:[])];
    if(repositories.some(repository=>!projectRepositoryMatches(repository,e.repo)))errors.push('Transferred PR/run repository identity differs from the fixed project');
  }
  if(early)errors.push(...verifyHistoricalAutoFull(e.prFull,preflight,e.identityWitness));
  if(preflight.schemaVersion===6)errors.push(...verifyFastQueueFull(e.queueFull,preflight,e.pr?.merge_commit_sha));
  if(![2,3].includes(e.schemaVersion))errors.push('Missing versioned merged evidence');
  if(e.repo!==preflight.repo&&!transferred)errors.push('Merged evidence repository differs from preflight');
  if(preflight.review?.disposition==='low-risk-docs'&&
    (e.changedFileCount!==preflight.changedFileCount||JSON.stringify(e.changedFiles)!==JSON.stringify(preflight.changedFiles)))
    errors.push('Post-merge GitHub files differ from the verified low-risk waiver');
  if(e.pr?.number!==preflight.prNumber||!e.pr?.merged||e.pr?.state!=='closed')errors.push('Expected the verified PR to be merged');
  if(e.pr?.head?.sha!==preflight.head||e.pr?.base?.ref!==preflight.baseRef)errors.push('Merged PR head/target differs from preflight');
  if(!validSha(e.commit?.sha)||e.commit?.sha!==e.pr?.merge_commit_sha)errors.push('Actual merged commit does not match merge_commit_sha');
  if(JSON.stringify(parentShas(e.commit))!==JSON.stringify([preflight.base]))errors.push('Actual squash parent differs from verified base; obtain fresh evidence for the new combination');
  if(!validSha(e.commit?.commit?.tree?.sha)||e.commit?.commit?.tree?.sha!==preflight.sourceTree)errors.push('Actual merged source tree differs from the verified source tree');
  if(e.current?.number!==e.pr?.number||e.current?.head?.sha!==e.pr?.head?.sha||e.current?.base?.ref!==e.pr?.base?.ref||!e.current?.merged||e.current?.state!=='closed'||e.current?.merge_commit_sha!==e.pr?.merge_commit_sha)errors.push('Merged PR identity changed during verification');
  errors.push(...runErrors(e.run,{head:e.commit?.sha,event:'push',runId:e.run?.id,attempt:e.run?.run_attempt,branch:preflight.baseRef,repo:e.repo}));
  errors.push(...runErrors(e.currentRun,{head:e.commit?.sha,event:'push',runId:e.run?.id,attempt:e.run?.run_attempt,branch:preflight.baseRef,repo:e.repo}));
  errors.push(...qualityErrors(e.jobs,{attempt:e.run?.run_attempt,runId:e.run?.id,head:e.commit?.sha,schemaVersion:e.schemaVersion}));
  errors.push(...receiptErrors(e.checkout,e.checkoutArtifact,e.jobs,e.run,e.schemaVersion));
  for(const [field,value] of Object.entries({event:'push',runId:e.run?.id,tested:e.commit?.sha,head:e.commit?.sha,base:preflight.base})) {
    if(value===undefined||e.checkout?.[field]!==value)errors.push(`Merged checkout ${field} is missing, stale or mismatched`);
  }
  if(e.checkout?.prNumber!==undefined||JSON.stringify(e.checkout?.parents)!==JSON.stringify([preflight.base]))errors.push('Merged checkout is not the actual squash commit');
  return {state:errors.length?'merged_pending':'merged_passed',errors};
}

// This is historical PR CI collected AFTER native auto-merge. It is not a
// schema3 preflight and does not invent target-ref observations after merge.
// The surrounding merged verifier separately proves the actual squash parent
// and tree match the independently observed target/source in the saved arm.
export function verifyHistoricalAutoFull(e,arm,identityWitness){
  if(!e||e.schemaVersion!==5||e.kind!=='historical-auto-full')return ['Missing historical PR Full evidence'];
  const errors=[],run=e.run??{},checkout=e.checkout??{};
  const transferred=identityWitnessValid(identityWitness,arm,identityWitness?.canonicalFullName),repo=transferred?identityWitness.canonicalFullName:arm.repo;
  if(identityWitness!==undefined&&(!transferred||![run.repository,e.currentRun?.repository].every(r=>projectRepositoryMatches(r,repo))))
    errors.push('Historical Full repository transfer identity is invalid');
  errors.push(...runErrors(run,{head:arm.head,event:'pull_request',runId:run.id,attempt:run.run_attempt,repo}),
    ...runErrors(e.currentRun,{head:arm.head,event:'pull_request',runId:run.id,attempt:run.run_attempt,repo}),
    ...qualityErrors(e.jobs,{attempt:run.run_attempt,runId:run.id,head:arm.head,schemaVersion:3}),
    ...receiptErrors(checkout,e.checkoutArtifact,e.jobs,run,3));
  if(!Array.isArray(run.pull_requests)||run.pull_requests.length>0&&!run.pull_requests.some(p=>p.number===arm.prNumber)||run.id<arm.pendingRun?.id||
    run.id===arm.pendingRun?.id&&run.run_attempt<arm.pendingRun.attempt)
    errors.push('Historical Full does not belong to the authorized PR/run');
  for(const [field,value]of Object.entries({head:arm.head,base:arm.base,tested:arm.tested,prNumber:arm.prNumber,event:'pull_request',runId:run.id}))
    if(checkout[field]!==value)errors.push('Historical PR checkout differs from authorization: '+field);
  if(JSON.stringify(checkout.parents)!==JSON.stringify([arm.base,arm.head])||e.testedCommit?.sha!==arm.tested||
    JSON.stringify(parentShas(e.testedCommit))!==JSON.stringify([arm.base,arm.head])||e.testedCommit?.commit?.tree?.sha!==arm.sourceTree)
    errors.push('Historical PR tested commit/parents/tree differs from authorization');
  return errors;
}
// Fast PR evidence authorizes entry only. A separate immutable Full run must
// certify the native queue's actual squash SHA, followed by ordinary push Full.
export function verifyFastQueueFull(e,arm,mergedSha){
  if(!e||e.schemaVersion!==8||e.kind!=='fast-queue-full')return ['Missing native queue Full evidence for Fast PR'];
  const run=e.run??{},errors=[];
  errors.push(...runErrors(run,{head:mergedSha,event:'merge_group',runId:run.id,attempt:run.run_attempt,repo:arm.repo}),
    ...runErrors(e.currentRun,{head:mergedSha,event:'merge_group',runId:run.id,attempt:run.run_attempt,repo:arm.repo}),
    ...qualityErrors(e.jobs,{attempt:run.run_attempt,runId:run.id,head:mergedSha,schemaVersion:3}),
    ...receiptErrors(e.checkout,e.checkoutArtifact,e.jobs,run,3));
  if(run.head_branch!==`gh-readonly-queue/develop/pr-${arm.prNumber}-${arm.base}`)
    errors.push('Queue Full does not belong to the authorized PR/BASE');
  for(const [field,value]of Object.entries({schemaVersion:1,event:'merge_group',runId:run.id,
    tested:mergedSha,head:mergedSha,base:arm.base}))
    if(e.checkout?.[field]!==value)errors.push('Queue Full checkout differs: '+field);
  if(e.checkout?.prNumber!=null||JSON.stringify(e.checkout?.parents)!==JSON.stringify([arm.base]))
    errors.push('Queue Full checkout must be the exact native squash');
  for(const context of ['full-quality','pr-quality','independent-review']){
    const status=e.statuses?.filter(s=>s.context===context).sort((a,b)=>b.id-a.id)[0];
    if(!positiveId(status?.id)||status.state!=='success'||status.creator?.id!==41898282||
      status.creator?.login!=='github-actions[bot]'||
      status.target_url!==`https://github.com/${arm.repo}/actions/runs/${run.id}`)
      errors.push('Queue Full/admission status is missing or no longer successful: '+context);
  }
  const licenses=e.licenses;
  if(!positiveId(licenses?.run?.id)||!positiveId(licenses?.run?.run_attempt)||
    licenses.run.head_sha!==mergedSha||licenses.run.event!=='merge_group'||
    licenses.run.status!=='completed'||licenses.run.conclusion!=='success'||
    licenses.run.path!=='.github/workflows/licenses.yml'||licenses.run.repository?.full_name!==arm.repo||
    licenses.currentRun?.id!==licenses.run.id||licenses.currentRun?.run_attempt!==licenses.run.run_attempt||
    licenses.currentRun?.status!=='completed'||licenses.currentRun?.conclusion!=='success'||
    licenses.currentRun?.event!=='merge_group'||licenses.currentRun?.path!==licenses.run.path||
    licenses.currentRun?.head_sha!==mergedSha||licenses.currentRun?.repository?.full_name!==arm.repo||
    !Array.isArray(licenses.jobs)||licenses.jobs.length!==1||!positiveId(licenses.jobs[0]?.id)||
    licenses.jobs[0].name!=='inventory'||licenses.jobs[0].run_id!==licenses.run.id||
    licenses.jobs[0].run_attempt!==licenses.run.run_attempt||licenses.jobs[0].head_sha!==mergedSha||
    licenses.jobs[0].status!=='completed'||licenses.jobs[0].conclusion!=='success')
    errors.push('Queue inventory is missing, stale or unsuccessful');
  return errors;
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
function lowRiskFiles(query,repo,number,expectedCount) {
  const response=JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/pulls/${number}/files?per_page=100`));
  if(!Array.isArray(response)||!response.length||response.some(page=>!Array.isArray(page)))
    throw new Error('Low-risk waiver cannot read complete PR file pages');
  const files=response.flatMap(page=>page.map(file=>({filename:file?.filename,status:file?.status,sha:file?.sha})))
    .sort((a,b)=>a.filename<b.filename?-1:a.filename>b.filename?1:0);
  if(!isLowRiskDocumentationChange(files,expectedCount))
    throw new Error('Low-risk waiver denied: PR files are not exclusively eligible documentation');
  return files;
}
export function checkoutReceipt(repo,run,jobs,dir,query=gh,schemaVersion=deliverySchemaVersion,{allowRunningAggregate=false}={}) {
  const errors=qualityErrors(jobs,{attempt:run.run_attempt,runId:run.id,head:run.head_sha,schemaVersion,allowRunningAggregate});
  if(errors.length)throw new Error(errors.join('\n'));
  const attempt=receiptExecutionAttempt(jobs,schemaVersion);
  if(!positiveId(attempt))throw new Error('Cannot prove first rules shard execution attempt');
  const name=`quality-${run.id}-${attempt}-check`;
  const artifacts=pages(query,`repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`,'artifacts').filter(a=>a?.name===name);
  const artifact=artifacts[0];
  if(artifacts.length!==1||receiptErrors({schemaVersion:1,attempt},artifact,jobs,run,schemaVersion).length)throw new Error('Missing, duplicate, expired or mismatched checkout artifact');
  query('run','download',String(run.id),'--repo',repo,'--name',name,'--dir',dir);
  // Artifacts are immutable. Recheck the ID after name-based gh download so a
  // concurrent deletion/replacement cannot change the object we just accepted.
  const current=JSON.parse(query('api',`repos/${repo}/actions/artifacts/${artifact.id}`));
  if(current.id!==artifact.id||current.name!==name||receiptErrors({schemaVersion:1,attempt},current,jobs,run,schemaVersion).length)throw new Error('Checkout artifact changed during download');
  return {checkout:JSON.parse(readFileSync(join(dir,'ci-checkout.json'),'utf8')),checkoutArtifact:artifact};
}
function latestQualityRun(query,repo,{event,head,branch,number,allowMissingPrLink=false}) {
  const runs=pages(query,`repos/${repo}/actions/workflows/quality.yml/runs?event=${event}&head_sha=${head}&per_page=100`,'workflow_runs');
  return runs.filter(run=>run.head_sha===head&&run.event===event&&
    (branch===undefined||run.head_branch===branch)&&
    (number===undefined||Array.isArray(run.pull_requests)&&(run.pull_requests.some(pr=>pr.number===number)||allowMissingPrLink&&run.pull_requests.length===0)))
    .sort((a,b)=>b.id-a.id)[0];
}
function targetHead(query,repo,baseRef) {
  if(!['develop','master'].includes(baseRef))throw new Error('Unexpected target branch');
  const ref=JSON.parse(query('api',`repos/${repo}/git/ref/heads/${baseRef}`));
  if(ref?.ref!==`refs/heads/${baseRef}`||ref.object?.type!=='commit'||!validSha(ref.object?.sha))
    throw new Error('Actual target Git ref is missing or malformed');
  return ref.object.sha;
}
export function collectPrDelivery(repo,number,review,query=gh,loadCheckout) {
  const pr=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  if(pr.state!=='open'||pr.merged)throw new Error('Preflight requires an open PR; use --merged with its saved preflight evidence after merge');
  // PR base.sha and refs/pull/*/merge can both retain the old combination after
  // the actual target advances. Read the independent branch ref, not that pair.
  const targetBeforeSha=targetHead(query,repo,pr.base.ref);
  if(targetBeforeSha!==pr.base.sha)throw new Error('PR base is stale: actual target branch differs before collection');
  const waived=review?.disposition==='low-risk-docs';
  if(waived&&pr.base.ref!=='develop')throw new Error('Low-risk waiver is only permitted for develop');
  const changedFileCount=waived?pr.changed_files:undefined;
  const changedFiles=waived?lowRiskFiles(query,repo,number,changedFileCount):undefined;
  if(waived)review={disposition:'low-risk-docs',reviewedHeadSha:pr.head.sha,reviewedBaseSha:pr.base.sha};
  const identity={event:'pull_request',head:pr.head.sha,number};
  const run=latestQualityRun(query,repo,identity);
  if(!run||run.status!=='completed'||run.conclusion!=='success')throw new Error('Current Quality run is missing or not successful');
  const jobs=pages(query,`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`,'jobs');
  const fast=jobs.some(job=>job.name==='fast (windows-2025)');
  if(!loadCheckout)loadCheckout=(r,j)=>{
    const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
    return fast?collectFastCheckout(repo,r,j,dir,query):checkoutReceipt(repo,r,j,dir,query);
  };
  const {checkout,checkoutArtifact,plan}=loadCheckout(run,jobs);
  if(checkout.tested!==pr.merge_commit_sha)throw new Error('CI did not test the current PR merge combination');
  const commit=JSON.parse(query('api',`repos/${repo}/commits/${checkout.tested}`));
  const evidence={schemaVersion:deliverySchemaVersion,repo,baseRef:pr.base.ref,sourceTree:commit.commit.tree.sha,testedCommit:commit,
    head:pr.head.sha,base:pr.base.sha,tested:checkout.tested,parents:commit.parents.map(p=>p.sha),
    runId:run.id,attempt:run.run_attempt,event:run.event,prNumber:number,run,jobs,checkout,checkoutArtifact,review,targetBeforeSha,
    ...(waived?{changedFileCount,changedFiles}:{})};
  if(fast)Object.assign(evidence,{schemaVersion:7,kind:'pr-fast',number,pr,target:targetBeforeSha,commit,plan});
  const current=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  if(fast)evidence.pr=current;
  evidence.currentRun=latestQualityRun(query,repo,identity);
  if(fast)evidence.latestRun=evidence.currentRun;
  evidence.targetAfterSha=targetHead(query,repo,pr.base.ref);
  return {evidence,current};
}
export function collectMergedDelivery(repo,number,preflight,query=gh,loadCheckout=(run,jobs)=>{
  const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
  return checkoutReceipt(repo,run,jobs,dir,query);
}) {
  const pr=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  if(!pr.merged||!validSha(pr.merge_commit_sha))throw new Error('PR is not merged; its passing preflight is only pr_passed');
  const commit=JSON.parse(query('api',`repos/${repo}/commits/${pr.merge_commit_sha}`));
  let prFull;
  if(preflight.schemaVersion===4&&preflight.fullPreflight===undefined){
    const identity={event:'pull_request',head:preflight.head,branch:pr.head.ref,number,allowMissingPrLink:true};
    const run=latestQualityRun(query,repo,identity);
    const jobs=run?.status==='completed'?pages(query,`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`,'jobs'):[];
    const receipt=run?.status==='completed'&&run.conclusion==='success'?loadCheckout(run,jobs):{};
    prFull={schemaVersion:5,kind:'historical-auto-full',run,jobs,...receipt,
      testedCommit:JSON.parse(query('api',`repos/${repo}/commits/${preflight.tested}`)),
      currentRun:latestQualityRun(query,repo,identity)};
  }
  const identity={event:'push',head:pr.merge_commit_sha,branch:pr.base.ref};
  const run=latestQualityRun(query,repo,identity);
  const jobs=run?.status==='completed'?pages(query,`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`,'jobs'):[];
  const receipt=run?.status==='completed'&&run.conclusion==='success'?loadCheckout(run,jobs):{};
  const current=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
  const currentRun=latestQualityRun(query,repo,identity);
  let queueFull;
  if(preflight.schemaVersion===6){
    const groupIdentity={event:'merge_group',head:pr.merge_commit_sha,
      branch:`gh-readonly-queue/develop/pr-${number}-${preflight.base}`};
    const groupRun=latestQualityRun(query,repo,groupIdentity);
    const groupJobs=groupRun?.status==='completed'?pages(query,`repos/${repo}/actions/runs/${groupRun.id}/jobs?filter=all&per_page=100`,'jobs'):[];
    const groupReceipt=groupRun?.conclusion==='success'?loadCheckout(groupRun,groupJobs):{};
    const statuses=JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/commits/${pr.merge_commit_sha}/statuses?per_page=100`)).flat();
    const licenseRuns=pages(query,`repos/${repo}/actions/workflows/licenses.yml/runs?event=merge_group&head_sha=${pr.merge_commit_sha}&per_page=100`,'workflow_runs');
    const licenseRun=licenseRuns.filter(r=>r.head_sha===pr.merge_commit_sha&&r.event==='merge_group').sort((a,b)=>b.id-a.id)[0];
    const licenseJobs=licenseRun?pages(query,`repos/${repo}/actions/runs/${licenseRun.id}/jobs?filter=all&per_page=100`,'jobs'):[];
    queueFull={schemaVersion:8,kind:'fast-queue-full',run:groupRun,jobs:groupJobs,...groupReceipt,statuses,
      currentRun:latestQualityRun(query,repo,groupIdentity),licenses:{run:licenseRun,jobs:licenseJobs,
        currentRun:pages(query,`repos/${repo}/actions/workflows/licenses.yml/runs?event=merge_group&head_sha=${pr.merge_commit_sha}&per_page=100`,'workflow_runs')
          .filter(r=>r.head_sha===pr.merge_commit_sha&&r.event==='merge_group').sort((a,b)=>b.id-a.id)[0]}};
  }
  const waived=preflight.review?.disposition==='low-risk-docs';
  const changedFileCount=waived?pr.changed_files:undefined;
  const changedFiles=waived?lowRiskFiles(query,repo,number,changedFileCount):undefined;
  return {schemaVersion:deliverySchemaVersion,repo,preflight,pr,commit,run,jobs,...receipt,current,currentRun,...(prFull?{prFull}:{}),...(queueFull?{queueFull}:{}),
    ...(waived?{changedFileCount,changedFiles}:{})};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [number,evidenceFile,mode,...extra]=process.argv.slice(2);
    if(!/^[1-9]\d*$/.test(number??'')||!evidenceFile||mode!==undefined&&mode!=='--merged'||extra.length)throw new Error('Usage: npm run verify:delivery -- <PR-number> <independent-review.json>|--low-risk-docs OR <PR-number> <preflight-evidence.json> --merged');
    const repo=gh('repo','view','--json','nameWithOwner','--jq','.nameWithOwner').trim();
    if(!projectRepositoryMatches(currentProjectRepository(gh),repo))throw Error('Current repository differs from the fixed project');
    const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
    if(mode==='--merged') {
      const preflightText=readFileSync(evidenceFile,'utf8'),preflight=JSON.parse(preflightText);
      const errors=[4,6].includes(preflight.schemaVersion)?verifyAutoMergeArm(preflight):verifyDelivery(preflight);
      const identityWitness=preflight.repo!==repo?collectIdentityWitness(preflightText,repo,gh):undefined;
      if(preflight.prNumber!==Number(number)||errors.length)throw new Error('Preflight evidence is invalid, stale or belongs to a different PR/repository');
      const evidence=collectMergedDelivery(repo,Number(number),preflight,gh,(run,jobs)=>checkoutReceipt(repo,run,jobs,join(dir,String(run.id))));
      if(identityWitness)evidence.identityWitness=identityWitness;
      const result=verifyMergedDelivery(evidence);
      writeFileSync(join(dir,'evidence.json'),JSON.stringify({...evidence,...result},null,2)+'\n');
      console.log(`Delivery state: ${result.state}; actual merged commit ${evidence.pr.merge_commit_sha}; evidence ${dir}`);
      if(result.errors.length)throw new Error(result.errors.join('\n'));
      process.exitCode=0;
    } else {
      const {evidence,current}=collectPrDelivery(repo,Number(number),evidenceFile==='--low-risk-docs'?{disposition:'low-risk-docs'}:JSON.parse(readFileSync(evidenceFile,'utf8')),gh,
        (run,jobs)=>jobs.some(job=>job.name==='fast (windows-2025)')?collectFastCheckout(repo,run,jobs,dir,gh):checkoutReceipt(repo,run,jobs,dir));
      const errors=verifyDelivery(evidence);
      if(current.state!=='open'||current.merged||current.head.sha!==evidence.head||current.base.sha!==evidence.base||current.base.ref!==evidence.baseRef||current.merge_commit_sha!==evidence.tested)errors.push('PR head/base/merge combination changed during verification');
      writeFileSync(join(dir,'evidence.json'),JSON.stringify({...evidence,state:errors.length?'pr_pending':'pr_passed',errors},null,2)+'\n');
      if(errors.length)throw new Error(errors.join('\n'));
      console.log(`Delivery state: pr_passed; evidence ${dir}; merge with --match-head-commit ${evidence.head}. Then run verify:delivery -- ${number} ${join(dir,'evidence.json')} --merged. External reviewer provenance must still be inspected when required.`);
    }
  }catch(error){console.error(error.message);process.exitCode=1;}
}
