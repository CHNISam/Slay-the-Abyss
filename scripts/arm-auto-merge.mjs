import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {isLowRiskDocumentationChange} from './verify-delivery.mjs';

// Status on the reviewed HEAD, not a general-purpose label or an old CI run.
// This status MUST be required by the develop ruleset before arming is allowed.
export const reviewContext='independent-review';
export const requiredContexts=['check','presentation','engineering-posix','inventory',reviewContext];
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
  if(!prId(pr?.number)||pr?.state!=='open'||pr?.merged||pr?.draft)errors.push('PR must be open, ready and unmerged');
  if(pr?.base?.ref!=='develop'||!validSha(pr?.base?.sha)||!validSha(pr?.head?.sha))
    errors.push('PR must target develop with valid HEAD and BASE SHAs');
  if(pr?.head?.repo?.full_name!==repo)errors.push('Cross-repository PRs require manual handling');
  if(pr?.mergeable!==true)errors.push('PR mergeability is conflicting or unknown');
  if(!validSha(baseSha)||pr?.base?.sha!==baseSha)errors.push('Actual develop tip differs from the current PR base');
  const labels=(pr?.labels??[]).map(label=>(typeof label==='string'?label:label?.name??'').toLowerCase());
  if(labels.some(label=>['hold','blocked','do-not-merge','manual-merge','merge:manual','risk:critical'].includes(label)))
    errors.push('PR has a manual/blocked merge label');
  if(!ruleset||ruleset.enforcement!=='active'||!ruleset.conditions?.ref_name?.include?.includes('refs/heads/develop'))
    errors.push('Active develop ruleset is missing');
  const rules=ruleset?.rules??[];
  const checks=rules.find(rule=>rule.type==='required_status_checks');
  const actualChecks=checks?.parameters?.required_status_checks??[];
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
  if(!Array.isArray(dependencies)||dependencies.some(dep=>dep?.merged!==true))
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

function gh(...args) {
  const p=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
  if(p.error||p.status!==0)throw Error('GitHub CLI failed: '+(p.error?.message??p.stderr??'unknown error'));
  return p.stdout;
}
function json(query,...args) {return JSON.parse(query(...args));}

export function collectEligibility(repo,number,review,query=gh) {
  const pr=json(query,'api','repos/'+repo+'/pulls/'+number);
  const settings=json(query,'api','repos/'+repo);
  const ruleset=json(query,'api','repos/'+repo+'/rulesets/25870651');
  const target=json(query,'api','repos/'+repo+'/git/ref/heads/develop');
  if(target?.ref!=='refs/heads/develop'||target.object?.type!=='commit'||!validSha(target.object.sha))
    throw Error('Cannot read the actual develop commit');
  const dependsOn=parseDependencies(pr.body);
  if(dependsOn.includes(number))throw Error('PR cannot depend on itself');
  const dependencies=dependsOn.map(id=>json(query,'api','repos/'+repo+'/pulls/'+id));
  let changedFiles;
  if(review?.disposition==='low-risk-docs') {
    const pages=json(query,'api','--paginate','--slurp','repos/'+repo+'/pulls/'+number+'/files?per_page=100');
    if(!Array.isArray(pages)||!pages.length||pages.some(page=>!Array.isArray(page)))
      throw Error('Cannot read all changed files for a low-risk waiver');
    changedFiles=pages.flat().map(file=>({filename:file?.filename,status:file?.status,sha:file?.sha}));
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

export function armAutoMerge(repo,number,review,query=gh,{dryRun=false}={}) {
  const before=collectEligibility(repo,number,review,query);
  if(before.errors.length)throw Error(before.errors.join('\n'));
  // Read the actual branch ref and PR a second time immediately before writing.
  const current=collectEligibility(repo,number,review,query);
  if(current.errors.length||before.headSha!==current.headSha||before.baseSha!==current.baseSha)
    throw Error('PR or review eligibility changed while preparing auto-merge: '+current.errors.join('; '));
  if(before.tested!==current.tested||before.sourceTree!==current.sourceTree)
    throw Error('Proposed merge commit changed while preparing auto-merge');
  const proof={schemaVersion:4,kind:'auto-merge-arm',repo,prNumber:number,baseRef:'develop',
    head:current.headSha,base:current.baseSha,tested:current.tested,parents:current.parents,
    sourceTree:current.sourceTree,review,targetBeforeSha:before.baseSha,targetAfterSha:current.baseSha,
    ...(review?.disposition==='low-risk-docs'?{changedFileCount:current.pr.changed_files,changedFiles:current.changedFiles}:{})};
  if(dryRun)return {state:'eligible',head:current.headSha,base:current.baseSha,dependsOn:current.dependsOn,proof};
  const desc=review?.disposition==='low-risk-docs'?'Verified narrow documentation waiver':
    'Independent review '+review.reviewId.slice(0,55);
  query('api','--method','POST','repos/'+repo+'/statuses/'+current.headSha,
    '-f','state=success','-f','context='+reviewContext,'-f','description='+desc);
  query('pr','merge',String(number),'--repo',repo,'--auto','--squash',
    '--match-head-commit',current.headSha);
  const after=json(query,'api','repos/'+repo+'/pulls/'+number);
  if(after.head?.sha!==current.headSha||after.base?.ref!=='develop')
    throw Error('PR changed during auto-merge activation; recheck it immediately');
  return {state:after.merged?'merged':'auto-merge-requested',head:current.headSha,
    base:current.baseSha,dependsOn:current.dependsOn,proof};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [numberArg,reviewArg,option,...extra]=process.argv.slice(2);
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
    const result=armAutoMerge('CHNISam/Slay-the-Abyss',Number(numberArg),review,gh,
      {dryRun:option==='--dry-run'});
    const dir='build/delivery';mkdirSync(dir,{recursive:true});
    const proofFile=dir+'/auto-merge-'+numberArg+'-'+result.head.slice(0,12)+'.json';
    if(option!=='--dry-run')writeFileSync(proofFile,JSON.stringify(result.proof,null,2)+'\n');
    console.log(JSON.stringify({state:result.state,head:result.head,base:result.base,
      dependsOn:result.dependsOn,...(option!=='--dry-run'?{proofFile}:{})},null,2));
    console.log(option==='--dry-run'?'Read-only eligibility PASS':
      'GitHub controls the required CI. After merge: npm run verify:delivery -- '+numberArg+' '+proofFile+' --merged');
  }catch(error){console.error(error.message);process.exitCode=1;}
}
