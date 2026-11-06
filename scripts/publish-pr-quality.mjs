import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {main as fullMain,beginFullQuality} from './publish-full-quality.mjs';
import {prFastErrors,collectFastCheckout} from './pr-quality-evidence.mjs';

export const prQualityContext='pr-quality';
function gh(...args){
 const p=spawnSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024});
 if(p.error||p.status!==0)throw Error('PR quality query failed: '+(p.error?.message??p.stderr));
 return p.stdout;
}
export function main(env=process.env,query=gh,{pending=false,loadCheckout}={}){
 const event=JSON.parse(readFileSync(env.GITHUB_EVENT_PATH,'utf8')),pr=event.pull_request;
 if(env.GITHUB_EVENT_NAME!=='pull_request'||pr?.base?.ref!=='develop'||pr.head?.repo?.full_name!==env.GITHUB_REPOSITORY)return;
 if(!pending&&env.FULL_MODE==='full')return fullMain(env,query,{context:prQualityContext,loadCheckout});
 const repo=env.GITHUB_REPOSITORY,head=pr.head.sha,number=pr.number,runId=Number(env.GITHUB_RUN_ID),attempt=Number(env.GITHUB_RUN_ATTEMPT);
 const get=p=>JSON.parse(query('api',`repos/${repo}/${p}`));
 const pages=(p,key)=>JSON.parse(query('api','--paginate','--slurp',`repos/${repo}/${p}`)).flatMap(page=>page[key]);
 const latest=()=>pages(`actions/workflows/quality.yml/runs?event=pull_request&head_sha=${head}&per_page=100`,'workflow_runs')
  .filter(r=>r.head_sha===head&&r.pull_requests?.some(p=>p.number===number)).sort((a,b)=>b.id-a.id)[0];
 const run=get('actions/runs/'+runId),latestRun=latest();
 if(pending)return beginFullQuality({repo,head,number,runId,attempt,run,latestRun,pr:get('pulls/'+number)},query,prQualityContext);
 const current=()=>{
  const active=get('actions/runs/'+runId),newest=latest();
  return newest?.id===runId&&newest.run_attempt===attempt&&active.run_attempt===attempt&&
   active.status==='in_progress'&&active.conclusion==null;
 };
 if(!current())return {state:'superseded'};
 const evidence={repo,head,number,base:pr.base.sha,tested:env.GITHUB_SHA,runId,attempt,run,latestRun,
  mode:env.FULL_MODE,needs:JSON.parse(env.FULL_NEEDS),jobs:pages(`actions/runs/${runId}/jobs?filter=all&per_page=100`,'jobs'),
  pr:get('pulls/'+number),target:get('git/ref/heads/develop').object?.sha,commit:get('commits/'+env.GITHUB_SHA)};
 let errors=env.FULL_MODE==='fast'?[]:['Unknown PR Quality mode'];
 errors.push(...prFastErrors(evidence,{allowRunningAggregate:true,metadataOnly:true}));
 if(!errors.length){
  const dir=mkdtempSync(join(tmpdir(),'abyss-fast-gate-'));
  try{Object.assign(evidence,(loadCheckout??((r,j)=>collectFastCheckout(repo,r,j,dir,query,{allowRunningAggregate:true})))(run,evidence.jobs));}
  catch(error){errors.push(error.message);}
  finally{rmSync(dir,{recursive:true,force:true});}
 }
 if(!current())return {state:'superseded'};
 evidence.run=get('actions/runs/'+runId);evidence.latestRun=latest();evidence.pr=get('pulls/'+number);evidence.target=get('git/ref/heads/develop').object?.sha;
 errors.push(...prFastErrors(evidence,{allowRunningAggregate:true}));
 const state=errors.length?'failure':'success';
 const written=JSON.parse(query('api','--method','POST',`repos/${repo}/statuses/${head}`,
  '-f','state='+state,'-f','context='+prQualityContext,
  '-f','description='+(errors.length?'PR quality unavailable: '+errors[0].slice(0,110):`Exact dual-platform Fast run ${runId}, attempt ${attempt}`),
  '-f',`target_url=https://github.com/${repo}/actions/runs/${runId}`));
 if(written.state!==state||written.context!==prQualityContext)throw Error('PR quality status write readback differs');
 if(errors.length)throw Error(errors.join('\n'));
 return {state,runId,head};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{console.log(JSON.stringify(main(process.env,gh,{pending:process.argv[2]==='--pending'})));}
 catch(error){console.error(error.message);process.exitCode=1;}
}
