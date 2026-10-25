import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const requiredJobs=['check','presentation','engineering-posix'];
export function verifyDelivery(e) {
  const errors=[];
  for(const field of ['head','base','tested'])if(!/^[a-f0-9]{40}$/.test(e[field]??''))errors.push(`Invalid ${field}`);
  if(e.event!=='pull_request'||!Number.isSafeInteger(e.runId)||!Number.isSafeInteger(e.attempt))errors.push('Expected PR run identity');
  for(const field of ['head','base','tested','runId','attempt','event','prNumber'])if(e.checkout?.[field]!==e[field])errors.push(`Checkout ${field} is stale or mismatched`);
  if(JSON.stringify(e.parents)!==JSON.stringify([e.base,e.head]))errors.push('Tested merge parents do not match current base/head');
  for(const name of requiredJobs) {
    const found=e.jobs?.filter(job=>job.name===name)??[];
    if(found.length!==1||found[0].status!=='completed'||found[0].conclusion!=='success'||found[0].run_attempt!==e.attempt)errors.push(`Required job ${name} is missing, incomplete, unsuccessful or stale`);
  }
  if(e.review?.reviewedHeadSha!==e.head||e.review?.reviewedBaseSha!==e.base||!e.review?.reviewId||e.review?.conclusion!=='pass'||!Array.isArray(e.review?.unresolved)||e.review.unresolved.length)errors.push('Review is missing, stale, or has unresolved findings');
  return errors;
}
function gh(...args) {
  const result=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
  if(result.error||result.status!==0)throw new Error(`GitHub query failed: ${result.error?.message||result.stderr}`);return result.stdout;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [number,reviewFile]=process.argv.slice(2);if(!/^\d+$/.test(number??'')||!reviewFile)throw new Error('Usage: npm run verify:delivery -- <PR-number> <independent-review.json>');
    const repo=gh('repo','view','--json','nameWithOwner','--jq','.nameWithOwner').trim();
    const pr=JSON.parse(gh('api',`repos/${repo}/pulls/${number}`));
    const runs=JSON.parse(gh('api','--paginate','--slurp',`repos/${repo}/actions/workflows/quality.yml/runs?event=pull_request&head_sha=${pr.head.sha}&per_page=100`)).flatMap(page=>page.workflow_runs);
    const run=runs.filter(run=>run.pull_requests.some(item=>item.number===Number(number))).sort((a,b)=>b.id-a.id)[0];
    if(!run||run.status!=='completed'||run.conclusion!=='success')throw new Error('Current Quality run is missing or not successful');
    const jobs=JSON.parse(gh('api','--paginate','--slurp',`repos/${repo}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`)).flatMap(page=>page.jobs);
    const dir=join('build/delivery',randomUUID());mkdirSync(dir,{recursive:true});
    gh('run','download',String(run.id),'--repo',repo,'--name',`quality-${run.id}-${run.run_attempt}-check`,'--dir',dir);
    const checkout=JSON.parse(readFileSync(join(dir,'ci-checkout.json'),'utf8'));
    if(checkout.tested!==pr.merge_commit_sha)throw new Error('CI did not test the current PR merge combination');
    const commit=JSON.parse(gh('api',`repos/${repo}/commits/${checkout.tested}`));
    const evidence={head:pr.head.sha,base:pr.base.sha,tested:checkout.tested,parents:commit.parents.map(p=>p.sha),
      runId:run.id,attempt:run.run_attempt,event:run.event,prNumber:Number(number),jobs,checkout,
      review:JSON.parse(readFileSync(reviewFile,'utf8'))};
    const errors=verifyDelivery(evidence);
    const current=JSON.parse(gh('api',`repos/${repo}/pulls/${number}`));
    if(current.head.sha!==evidence.head||current.base.sha!==evidence.base)errors.push('PR head/base changed during verification');
    writeFileSync(join(dir,'evidence.json'),JSON.stringify({...evidence,errors},null,2)+'\n');
    if(errors.length)throw new Error(errors.join('\n'));
    console.log(`Delivery evidence passed: ${dir}; merge with --match-head-commit ${evidence.head} and recheck the resulting commit. Review provenance must still be independently inspected.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
