import {parseDependencies} from './arm-auto-merge.mjs';
import {projectRepositoryId,projectRepositoryMatches} from './repository-identity.mjs';

const repo='FurinyaWorks/Slay-the-Abyss';
const validSha=value=>typeof value==='string'&&/^[a-f0-9]{40}$/.test(value);
const positive=value=>Number.isSafeInteger(value)&&value>0;
const queryText=`query {
 repository(owner:"FurinyaWorks",name:"Slay-the-Abyss") {
  databaseId nameWithOwner ref(qualifiedName:"refs/heads/develop") { target { oid } }
  mergeQueue(branch:"develop") { entries(first:100) {
   pageInfo { hasNextPage }
   nodes { id position state baseCommit { oid } headCommit { oid }
    pullRequest { number headRefOid baseRefName isDraft state mergeQueueEntry { id } }
   }
  } }
 }
}`;

// The native queue owns scheduling. This bounded, read-only admission check
// only releases a group whose live prefix and project-specific authorization
// can still be proven. Ambiguous/oversized queues require operator attention.
export function collectQueueAdmission(event,env,query){
 const response=JSON.parse(query('api','graphql','-f','query='+queryText));
 const repository=response?.data?.repository;
 const entries=repository?.mergeQueue?.entries;
 const base=event.merge_group.base_sha;
 if(response.errors?.length||repository?.databaseId!==projectRepositoryId||repository.nameWithOwner!==repo||
  repository.ref?.target?.oid!==base||entries?.pageInfo?.hasNextPage!==false||!Array.isArray(entries.nodes))
  throw Error('Current native queue repository, BASE or complete membership cannot be verified');
 const liveRef=JSON.parse(query('api',`repos/${repo}/git/ref/heads/${env.GITHUB_REF.slice('refs/heads/'.length)}`));
 if(liveRef?.ref!==env.GITHUB_REF||liveRef.object?.type!=='commit'||liveRef.object.sha!==env.GITHUB_SHA)
  throw Error('Current native group ref no longer matches this event');
 const ordered=[...entries.nodes].sort((a,b)=>a.position-b.position);
 const matches=ordered.filter(entry=>entry.headCommit?.oid===env.GITHUB_SHA);
 if(matches.length!==1)throw Error('Current native group has missing or ambiguous queue membership');
 const members=ordered.filter(entry=>entry.position<=matches[0].position);
 const ids=new Set(),numbers=new Set(),snapshot=[];
 if(!members.length||members.length!==matches[0].position||members[0].baseCommit?.oid!==base)
  throw Error('Native group prefix is incomplete or has changed BASE');
 for(const [index,entry] of members.entries()){
  const p=entry.pullRequest;
  if(typeof entry.id!=='string'||!entry.id||ids.has(entry.id)||entry.position!==index+1||
   !['AWAITING_CHECKS','MERGEABLE'].includes(entry.state)||
   !validSha(entry.baseCommit?.oid)||!validSha(entry.headCommit?.oid)||
   index>0&&entry.baseCommit.oid!==base&&entry.baseCommit.oid!==members[index-1].headCommit.oid||
   !positive(p?.number)||numbers.has(p.number)||!validSha(p.headRefOid)||p.state!=='OPEN'||p.isDraft!==false||
   p.baseRefName!=='develop'||p.mergeQueueEntry?.id!==entry.id)
   throw Error('Current native group prefix identity or state is invalid');
  ids.add(entry.id);numbers.add(p.number);
  const pr=JSON.parse(query('api',`repos/${repo}/pulls/${p.number}`));
  const labels=pr.labels;
  if(pr.number!==p.number||pr.state!=='open'||pr.merged!==false||pr.draft!==false||
   pr.head?.sha!==p.headRefOid||!projectRepositoryMatches(pr.head?.repo,repo)||
   pr.base?.ref!=='develop'||pr.base.sha!==base||!projectRepositoryMatches(pr.base?.repo,repo)||
   !Array.isArray(labels)||labels.some(label=>!label||typeof label.name!=='string'||
    ['hold','blocked','do-not-merge','manual-merge','merge:manual','risk:critical'].includes(label.name.toLowerCase())))
   throw Error('Queue PR is held, changed or no longer eligible: '+p.number);
  const statuses=JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/commits/${p.headRefOid}/statuses?per_page=100`));
  if(!Array.isArray(statuses)||!statuses.length||statuses.some(page=>!Array.isArray(page)))
   throw Error('Complete current review status pages are missing');
  const review=statuses.flat().filter(s=>s?.context==='independent-review').sort((a,b)=>b.id-a.id)[0];
  if(!positive(review?.id)||review.state!=='success'||typeof review.description!=='string'||
   !review.description.endsWith(` [base:${base}]`))
   throw Error('Queue PR review is paused, missing or bound to a different BASE: '+p.number);
  const dependencies=parseDependencies(pr.body),dependencyEvidence=[];
  for(const number of dependencies){
   if(number===p.number)throw Error('Queue PR cannot depend on itself');
   const dep=JSON.parse(query('api',`repos/${repo}/pulls/${number}`));
   if(dep.number!==number||dep.merged!==true||dep.base?.ref!=='develop'||
    !projectRepositoryMatches(dep.base?.repo,repo)||!validSha(dep.merge_commit_sha))
    throw Error('Queue PR dependency is not confirmed merged: '+number);
   const comparison=JSON.parse(query('api',`repos/${repo}/compare/${dep.merge_commit_sha}...${base}`));
   if(!['ahead','identical'].includes(comparison.status)||comparison.merge_base_commit?.sha!==dep.merge_commit_sha)
    throw Error('Queue PR dependency is not contained in the group BASE: '+number);
   dependencyEvidence.push({number,merge:dep.merge_commit_sha});
  }
  snapshot.push({id:entry.id,position:entry.position,base:entry.baseCommit.oid,head:entry.headCommit.oid,
   number:p.number,prHead:p.headRefOid,review:review.id,dependencies:dependencyEvidence});
 }
 return JSON.stringify(snapshot);
}
