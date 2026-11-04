import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {collectPrDelivery,verifyDelivery,isLowRiskDocumentationChange} from './verify-delivery.mjs';

// Status on the reviewed HEAD, not a general-purpose label or an old CI run.
// This status MUST be required by the develop ruleset before arming is allowed.
export const reviewContext='independent-review';
export const requiredContexts=['check','presentation','engineering-posix','inventory','full-quality',reviewContext];
const validSha=sha=>typeof sha==='string'&&/^[0-9a-f]{40}$/.test(sha);
const prId=id=>Number.isSafeInteger(id)&&id>0;

export function parseDependencies(body) {
  const declarations=[...(body??'').matchAll(/^\s*Depends-on:\s*(.*?)\s*$/gim)];
  if(declarations.length!==1)throw Error('PR body must declare exactly one Depends-on: none or Depends-on: #123, #456 line');
  const value=declarations[0][1].trim();
  if(/^none$/i.test(value))return [];
  const entries=value.split(/[\s,]+/).filter(Boolean);
  if(!entries.length||entries.some(item=>!/^#[1-9][0-9]*$/.test(item)))
    throw Error('Invalid Depends-on: use none or comma-separated #PR numbers in this repository');
  return [...new Set(entries.map(item=>Number(item.slice(1))))];
}

export function autoMergeErrors({repo,settings,pr,baseSha,ruleset,review,dependencies,changedFiles}) {
  const errors=[];
  if(repo!=='CHNISam/Slay-the-Abyss')errors.push('Unexpected repository');
  if(settings?.allow_auto_merge!==true||settings?.allow_squash_merge!==true)
    errors.push('Repository auto-merge and squash must both be enabled');
  if(!prId(pr?.number)||typeof pr?.node_id!=='string'||!pr.node_id.trim()||pr?.state!=='open'||pr?.merged||pr?.draft)errors.push('PR must be open, ready and unmerged');
  if(pr?.base?.ref!=='develop'||!validSha(pr?.base?.sha)||!validSha(pr?.head?.sha))
    errors.push('PR must target develop with valid HEAD and BASE SHAs');
  if(pr?.head?.repo?.full_name!==repo)errors.push('Cross-repository PRs require manual handling');
  if(pr?.mergeable!==true)errors.push('PR mergeability is conflicting or unknown');
  if(!validSha(baseSha)||pr?.base?.sha!==baseSha)errors.push('Actual develop tip differs from the current PR base');
  const labels=(pr?.labels??[]).map(label=>(typeof label==='string'?label:label?.name??'').toLowerCase());
  if(labels.some(label=>['hold','blocked','do-not-merge','manual-merge','merge:manual','risk:critical'].includes(label)))
    errors.push('PR has a manual/blocked merge label');
  // Conservative scope: reject unsupported/glob rules rather than assume they protect develop.
  if(!ruleset||ruleset.target!=='branch'||ruleset.enforcement!=='active'||
    JSON.stringify(ruleset.conditions?.ref_name?.include)!==JSON.stringify(['refs/heads/develop'])||
    !Array.isArray(ruleset.conditions?.ref_name?.exclude)||ruleset.conditions.ref_name.exclude.length)
    errors.push('Active develop ruleset is missing');
  const rules=ruleset?.rules??[];
  const checks=rules.find(rule=>rule.type==='required_status_checks');
  const actualChecks=checks?.parameters?.required_status_checks??[];
  if(checks?.parameters?.strict_required_status_checks_policy!==true)
    errors.push('Auto-merge requires strict up-to-date branch protection; current non-strict queue cannot preserve reviewed BASE');
  for(const context of requiredContexts)if(!actualChecks.some(check=>check.context===context))
    errors.push('Required status check missing from develop ruleset: '+context);
  for(const context of requiredContexts.filter(name=>name!==reviewContext))
    if(!actualChecks.some(check=>check.context===context&&check.integration_id===15368))
      errors.push('Existing CI check must retain GitHub Actions as its required source: '+context);
  if(actualChecks.some(check=>check.context===reviewContext&&check.integration_id!=null))
    errors.push('independent-review must accept the status source used by the review coordinator');
  const pull=rules.find(rule=>rule.type==='pull_request');
  if(!pull?.parameters?.allowed_merge_methods?.includes('squash')||
    pull.parameters.allowed_merge_methods.length!==1||pull.parameters.required_review_thread_resolution!==true||
    !rules.some(rule=>rule.type==='required_linear_history'))
    errors.push('develop must require squash-only PRs, resolved threads and linear history');
  if(!Array.isArray(dependencies)||dependencies.some(dep=>dep?.merged!==true||dep?.base?.ref!=='develop'||dep?.contained!==true))
    errors.push('A declared prerequisite PR is not confirmed merged');
  if(review?.disposition==='low-risk-docs') {
    if(!isLowRiskDocumentationChange(changedFiles,pr?.changed_files))
      errors.push('Low-risk waiver is not valid for the complete changed-file list');
  } else if(typeof review?.reviewId!=='string'||!review.reviewId.trim()||
    review?.conclusion!=='pass'||!Array.isArray(review?.unresolved)||review.unresolved.length)
    errors.push('Independent review is missing, unresolved, or unsuccessful');
  if(review?.reviewedHeadSha!==pr?.head?.sha||review?.reviewedBaseSha!==baseSha)
    errors.push('Review is stale for the current PR HEAD/BASE');
  if(review?.repo!=null&&review.repo!==repo||review?.prNumber!=null&&review.prNumber!==pr?.number)
    errors.push('Review belongs to a different repository/PR');
  return errors;
}

// Every unmerged readback must still name the reviewed PR and merge proposal.
// Comparing SHAs alone does not bind the target branch or repository identity.
function sameAdmission(actual,expected) {
  return actual?.number===expected.number&&actual.state==='open'&&actual.merged===false&&
    actual.draft===false&&actual.mergeable===true&&actual.base?.ref==='develop'&&
    actual.base.sha===expected.base.sha&&actual.head?.sha===expected.head.sha&&
    actual.head.repo?.full_name===expected.head.repo.full_name&&
    actual.merge_commit_sha===expected.merge_commit_sha&&actual.body===expected.body&&
    actual.changed_files===expected.changed_files&&
    JSON.stringify(actual.labels)===JSON.stringify(expected.labels);
}

function gh(...args) {
  const p=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
  if(p.error||p.status!==0)throw Error('GitHub CLI failed: '+(p.error?.message??p.stderr??'unknown error'));
  return p.stdout;
}
function json(query,...args) {return JSON.parse(query(...args));}

export function collectEligibility(repo,number,review,query=gh) {
  const pr=json(query,'api','repos/'+repo+'/pulls/'+number);
  if(pr?.number!==number)throw Error('GitHub returned a different PR identity');
  const settings=json(query,'api','repos/'+repo);
  const ruleset=json(query,'api','repos/'+repo+'/rulesets/25870651');
  const target=json(query,'api','repos/'+repo+'/git/ref/heads/develop');
  if(target?.ref!=='refs/heads/develop'||target.object?.type!=='commit'||!validSha(target.object.sha))
    throw Error('Cannot read the actual develop commit');
  const dependsOn=parseDependencies(pr.body);
  if(dependsOn.includes(number))throw Error('PR cannot depend on itself');
  const dependencies=dependsOn.map(id=>{
    const dep=json(query,'api','repos/'+repo+'/pulls/'+id);
    if(dep?.merged!==true||dep?.base?.ref!=='develop'||!validSha(dep.merge_commit_sha))return dep;
    const comparison=json(query,'api','repos/'+repo+'/compare/'+dep.merge_commit_sha+'...'+target.object.sha);
    return {...dep,contained:['ahead','identical'].includes(comparison?.status)&&
      comparison?.merge_base_commit?.sha===dep.merge_commit_sha};
  });
  let changedFiles;
  if(review?.disposition==='low-risk-docs') {
    const pages=json(query,'api','--paginate','--slurp','repos/'+repo+'/pulls/'+number+'/files?per_page=100');
    if(!Array.isArray(pages)||!pages.length||pages.some(page=>!Array.isArray(page)))
      throw Error('Cannot read all changed files for a low-risk waiver');
    changedFiles=pages.flat().map(file=>({filename:file?.filename,status:file?.status,sha:file?.sha}))
      .sort((a,b)=>a.filename<b.filename?-1:a.filename>b.filename?1:0);
  }
  if(!validSha(pr.merge_commit_sha))throw Error('GitHub has not produced the exact proposed merge commit');
  const testedCommit=json(query,'api','repos/'+repo+'/commits/'+pr.merge_commit_sha);
  const parents=(testedCommit.parents??[]).map(p=>p.sha);
  if(JSON.stringify(parents)!==JSON.stringify([target.object.sha,pr.head?.sha])||
    !validSha(testedCommit.commit?.tree?.sha))
    throw Error('Proposed merge commit is stale or lacks the reviewed source tree');
  const errors=autoMergeErrors({repo,pr,settings,baseSha:target.object.sha,ruleset,review,dependencies,changedFiles});
  return {pr,baseSha:target.object.sha,headSha:pr.head?.sha,dependsOn,errors,
    tested:pr.merge_commit_sha,parents,sourceTree:testedCommit.commit.tree.sha,changedFiles};
}

export function armAutoMerge(repo,number,review,query=gh,{dryRun=false,loadCheckout,persist=()=>{}}={}) {
  const before=collectEligibility(repo,number,review,query);
  if(before.errors.length)throw Error(before.errors.join('\n'));
  // Read the actual branch ref and PR a second time immediately before writing.
  const current=collectEligibility(repo,number,review,query);
  if(current.errors.length||before.headSha!==current.headSha||before.baseSha!==current.baseSha||
    !sameAdmission(current.pr,before.pr))
    throw Error('PR or review eligibility changed while preparing auto-merge: '+current.errors.join('; '));
  if(before.tested!==current.tested||before.sourceTree!==current.sourceTree)
    throw Error('Proposed merge commit changed while preparing auto-merge');
  const proof={schemaVersion:4,kind:'auto-merge-arm',repo,prNumber:number,baseRef:'develop',
    head:current.headSha,base:current.baseSha,tested:current.tested,parents:current.parents,
    sourceTree:current.sourceTree,review,targetBeforeSha:before.baseSha,targetAfterSha:current.baseSha,
    ...(review?.disposition==='low-risk-docs'?{changedFileCount:current.pr.changed_files,changedFiles:current.changedFiles}:{})};
  // The server-side full-quality context remains pending until the existing
  // aggregate has checked every actual shard. Review authorization can precede
  // that result without claiming a successful Full preflight.
  const latest=()=>{
    const pages=json(query,'api','--paginate','--slurp',`repos/${repo}/actions/workflows/quality.yml/runs?event=pull_request&head_sha=${current.headSha}&per_page=100`);
    return pages.flatMap(p=>p.workflow_runs).filter(r=>r.head_sha===current.headSha&&
      r.event==='pull_request'&&r.path==='.github/workflows/quality.yml'&&r.pull_requests?.some(p=>p.number===number))
      .sort((a,b)=>b.id-a.id)[0];
  };
  const verifyWitness=()=>{
    const run=latest(),expected=proof.fullPreflight?
      {id:proof.fullPreflight.runId,attempt:proof.fullPreflight.attempt}:proof.pendingRun;
    if(!run||run.id!==expected?.id||run.run_attempt!==expected.attempt||
      proof.fullPreflight&&(run.status!=='completed'||run.conclusion!=='success')||
      run.status==='completed'&&run.conclusion!=='success')throw Error('Latest Full run/attempt changed or failed before release');
    const jobs=json(query,'api','--paginate','--slurp',`repos/${repo}/actions/runs/${run.id}/jobs?filter=all&per_page=100`).flatMap(p=>p.jobs);
    const effective=new Map();
    for(const job of jobs)if(!effective.has(job.name)||effective.get(job.name).run_attempt<job.run_attempt)effective.set(job.name,job);
    if([...effective.values()].some(j=>['failure','cancelled','timed_out','action_required'].includes(j.conclusion)))
      throw Error('Latest Full job failed before release');
  };
  const pending=latest();
  if(!pending)throw Error('Current Quality run has not started; do not authorize missing CI');
  if(pending.status!=='completed'){
    const jobs=json(query,'api','--paginate','--slurp',`repos/${repo}/actions/runs/${pending.id}/jobs?filter=all&per_page=100`).flatMap(p=>p.jobs);
    if(!jobs.some(j=>/^rules \(\d+\/\d+\)$/.test(j.name))||jobs.some(j=>/^fast \(/.test(j.name)))
      throw Error('Full CI routing is not ready; add ci:full and wait for impact');
    const effective=new Map();
    for(const job of jobs)if(!effective.has(job.name)||effective.get(job.name).run_attempt<job.run_attempt)effective.set(job.name,job);
    if([...effective.values()].some(j=>['failure','cancelled','timed_out','action_required'].includes(j.conclusion)))
      throw Error('Current Full CI already failed or was cancelled');
    const final=collectEligibility(repo,number,review,query),lastRun=latest();
    if(final.errors.length||!sameAdmission(final.pr,current.pr)||lastRun?.id!==pending.id||lastRun.run_attempt!==pending.run_attempt)
      throw Error('PR admission or Full attempt changed before authorization');
    proof.pendingRun={id:pending.id,attempt:pending.run_attempt,head:pending.head_sha};
    return requestNativeMerge(repo,number,current,proof,review,query,{dryRun,persist,verifyWitness});
  }
  // Completed CI still uses the original exact Full proof, including its
  // immutable checkout artifact. Fast greens cannot take this path.
  const {evidence,current:fullCurrent}=collectPrDelivery(repo,number,review,query,loadCheckout);
  const fullErrors=verifyDelivery(evidence);
  if(fullErrors.length||evidence.schemaVersion!==3||evidence.head!==current.headSha||
    evidence.base!==current.baseSha||evidence.tested!==current.tested||
    evidence.sourceTree!==current.sourceTree||!sameAdmission(fullCurrent,current.pr))throw Error('Exact Full CI preflight failed: '+fullErrors.join('; '));
  const final=collectEligibility(repo,number,review,query);
  if(final.errors.length||final.headSha!==current.headSha||final.baseSha!==current.baseSha||
    final.tested!==current.tested||!sameAdmission(final.pr,current.pr))
    throw Error('PR admission changed during Full preflight');
  // Recheck current Full after the slower rules/dependency admission reads.
  // Reuse only the immutable artifact; a changed run/attempt fails its identity.
  const refreshed=collectPrDelivery(repo,number,review,query,()=>({
    checkout:evidence.checkout,checkoutArtifact:evidence.checkoutArtifact}));
  const refreshedErrors=verifyDelivery(refreshed.evidence);
  if(refreshedErrors.length||refreshed.evidence.runId!==evidence.runId||
    refreshed.evidence.attempt!==evidence.attempt||!sameAdmission(refreshed.current,current.pr))
    throw Error('Exact Full CI or admission changed before authorization: '+refreshedErrors.join('; '));
  proof.fullPreflight=refreshed.evidence;
  proof.review=refreshed.evidence.review;
  if(review?.disposition==='low-risk-docs')proof.changedFiles=refreshed.evidence.changedFiles;
  return requestNativeMerge(repo,number,current,proof,review,query,{dryRun,persist,verifyWitness});
}

function requestNativeMerge(repo,number,current,proof,review,query,{dryRun,persist,verifyWitness}){
  if(dryRun)return {state:'eligible',head:current.headSha,base:current.baseSha,dependsOn:current.dependsOn,proof};
  persist({state:'prepared',proof});
  const desc=review?.disposition==='low-risk-docs'?'Verified narrow documentation waiver':
    'Independent review '+review.reviewId.slice(0,55);
  const status=state=>{
    const created=json(query,'api','--method','POST','repos/'+repo+'/statuses/'+current.headSha,
      '-f','state='+state,'-f','context='+reviewContext,'-f','description='+
      (state==='pending'?'Review accepted; arming native auto-merge':desc));
    if(!prId(created.id)||created.state!==state||created.context!==reviewContext)throw Error('Review status write was not confirmed');
    return created;
  };
  const requirePending=id=>{
    const pages=json(query,'api','--paginate','--slurp',`repos/${repo}/commits/${current.headSha}/statuses?per_page=100`);
    const latest=pages.flat().filter(s=>s.context===reviewContext).sort((a,b)=>b.id-a.id)[0];
    if(latest?.id!==id||latest.state!=='pending')throw Error('Arming review gate was replaced or not confirmed');
  };
  try {
    persist({state:'authorizing',proof});
    const pending=status('pending');proof.reviewGate={pendingStatusId:pending.id};requirePending(pending.id);
    let after;
    for(let attempt=0;attempt<2;attempt++){
      let enableError;
      try{
        query('api','graphql','-f','query=mutation($id:ID!,$head:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,expectedHeadOid:$head,mergeMethod:SQUASH}){pullRequest{number}}}',
          '-f','id='+current.pr.node_id,'-f','head='+current.headSha);
      }catch(error){enableError=error;}
      after=json(query,'api','repos/'+repo+'/pulls/'+number);
      if(after.merged)throw Error('PR merged while the arming review gate was pending; handshake anomaly');
      if(!sameAdmission(after,current.pr))throw Error('PR admission changed during native activation');
      if(after.auto_merge?.merge_method==='squash')break;
      if(attempt===1||after.auto_merge!==null)throw enableError??Error('Native squash auto-merge was not confirmed');
      requirePending(pending.id);
    }
    persist({state:'native-queued',proof});
    const final=collectEligibility(repo,number,review,query);
    if(final.errors.length||!sameAdmission(final.pr,current.pr)||final.sourceTree!==current.sourceTree)
      throw Error('PR admission changed before review release');
    verifyWitness();requirePending(pending.id);
    persist({state:'releasing',proof});status('success');persist({state:'authorized',proof});
    after=json(query,'api','repos/'+repo+'/pulls/'+number);
    if(after.number!==number||after.head?.sha!==current.headSha||after.base?.ref!=='develop')
      throw Error('PR identity changed after review release');
    if(after.merged) {
      const commit=json(query,'api','repos/'+repo+'/commits/'+after.merge_commit_sha);
      if(after.state!=='closed'||JSON.stringify((commit.parents??[]).map(p=>p.sha))!==JSON.stringify([current.baseSha])||
        commit.commit?.tree?.sha!==current.sourceTree)throw Error('Merged identity differs from reviewed squash');
    } else if(!sameAdmission(after,current.pr)||after.auto_merge?.merge_method!=='squash')
      throw Error('Native squash auto-merge was not confirmed by readback');
    const result={state:after.merged?'merged':'auto-merge-requested',head:current.headSha,
      base:current.baseSha,dependsOn:current.dependsOn,proof};
    persist(result);return result;
  } catch(error) {
    // Even a failed API response may have committed. Revoke both authorizations,
    // and preserve cleanup failures instead of claiming the queue was cancelled.
    const cleanup=[];
    try {status('failure');}catch(e){cleanup.push('status revocation uncertain: '+e.message);}
    try {query('pr','merge',String(number),'--repo',repo,'--disable-auto');}
    catch(e){cleanup.push('auto-merge cancellation uncertain: '+e.message);}
    try {persist({state:'activation-failed',proof,error:error.message,cleanup});}
    catch(e){cleanup.push('evidence persistence failed: '+e.message);}
    throw Error(error.message+(cleanup.length?'\n'+cleanup.join('\n'):''));
  }
}

export function pauseAutoMerge(repo,number,query=gh){
  const endpoint=`repos/${repo}/pulls/${number}`,before=json(query,'api',endpoint);
  if(before.number!==number||before.state!=='open'||before.merged||before.base?.ref!=='develop'||!validSha(before.head?.sha))
    throw Error('Pause requires the open develop PR');
  query('pr','merge',String(number),'--repo',repo,'--disable-auto');
  const after=json(query,'api',endpoint);
  if(after.number!==number||after.state!=='open'||after.merged||after.auto_merge!==null||after.base?.ref!=='develop'||!validSha(after.head?.sha))
    throw Error('Native auto-merge cancellation was not confirmed; PR may already be merged');
  for(const head of new Set([before.head.sha,after.head.sha])){
    const status=json(query,'api','--method','POST',`repos/${repo}/statuses/${head}`,
      '-f','state=failure','-f','context='+reviewContext,'-f','description=Auto-merge explicitly paused; new authorization required');
    if(status.state!=='failure'||status.context!==reviewContext)throw Error('Review revocation readback failed');
  }
  return {state:'paused',prNumber:number,head:after.head.sha};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [numberArg,reviewArg,option,...extra]=process.argv.slice(2);
    if(/^[1-9][0-9]*$/.test(numberArg??'')&&reviewArg==='--pause'&&option===undefined&&!extra.length){
      console.log(JSON.stringify(pauseAutoMerge('CHNISam/Slay-the-Abyss',Number(numberArg)),null,2));
      process.exit(0);
    }
    if(!/^[1-9][0-9]*$/.test(numberArg??'')||!reviewArg||
      option!==undefined&&option!=='--dry-run'||extra.length)
      throw Error('Usage: npm run merge:auto -- <PR-number> <review.json>|--low-risk-docs [--dry-run]');
    const review=reviewArg==='--low-risk-docs'?{disposition:'low-risk-docs'}:
      JSON.parse(readFileSync(reviewArg,'utf8'));
    // Waiver is bound to the current SHA by the collector; no forged CI receipt.
    if(review.disposition==='low-risk-docs') {
      const first=json(gh,'api','repos/CHNISam/Slay-the-Abyss/pulls/'+Number(numberArg));
      review.reviewedHeadSha=first.head?.sha;
      review.reviewedBaseSha=first.base?.sha;
    }
    const dir='build/delivery';mkdirSync(dir,{recursive:true});
    const journal=dir+'/auto-merge-'+numberArg+'-'+randomUUID()+'-attempt.json';
    const result=armAutoMerge('CHNISam/Slay-the-Abyss',Number(numberArg),review,gh,
      {dryRun:option==='--dry-run',persist:record=>writeFileSync(journal,JSON.stringify(record,null,2)+'\n')});
    const proofFile=dir+'/auto-merge-'+numberArg+'-'+result.head.slice(0,12)+'.json';
    if(option!=='--dry-run')writeFileSync(proofFile,JSON.stringify(result.proof,null,2)+'\n');
    console.log(JSON.stringify({state:result.state,head:result.head,base:result.base,
      dependsOn:result.dependsOn,...(option!=='--dry-run'?{proofFile}:{})},null,2));
    console.log(option==='--dry-run'?'Read-only eligibility PASS':
      'GitHub controls the required CI. After merge: npm run verify:delivery -- '+numberArg+' '+proofFile+' --merged');
  }catch(error){console.error(error.message);process.exitCode=1;}
}
