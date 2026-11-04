import {writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {currentFullQualityJobs,qualityWorkflowPath} from '../../scripts/verify-delivery.mjs';
const sha=c=>c.repeat(40),repo='FurinyaWorks/Slay-the-Abyss';
export function admissionFixture(){
 const head=sha('a'),base=sha('b'),prHead=sha('c');
 const env={GITHUB_EVENT_NAME:'merge_group',GITHUB_REPOSITORY:repo,
  GITHUB_SHA:head,GITHUB_REF:'refs/heads/gh-readonly-queue/develop/pr-510-a',
  GITHUB_RUN_ID:'7',GITHUB_RUN_ATTEMPT:'1',FULL_MODE:'full'};
 const event={action:'checks_requested',repository:{id:1429751262,full_name:repo},
  merge_group:{head_sha:head,head_ref:env.GITHUB_REF,base_sha:base,base_ref:'refs/heads/develop'}};
 const run={id:7,run_attempt:1,event:'merge_group',head_sha:head,status:'in_progress',path:qualityWorkflowPath,repository:{full_name:repo}};
 const needs={impact:{result:'success'},rules:{result:'success'},fast:{result:'skipped'},presentation:{result:'success'},'engineering-posix':{result:'success'}};
 env.FULL_NEEDS=JSON.stringify(needs);
 const jobs=currentFullQualityJobs.map((name,i)=>({name,id:100+i,run_id:7,run_attempt:1,head_sha:head,
  status:name==='check'?'in_progress':'completed',conclusion:name==='check'?null:name==='fast'?'skipped':'success'}));
 const ruleset={target:'branch',enforcement:'active',bypass_actors:[],conditions:{ref_name:{include:['refs/heads/develop'],exclude:[]}},
  rules:[{type:'merge_queue',parameters:{merge_method:'SQUASH',grouping_strategy:'ALLGREEN'}},
   {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,required_status_checks:
    ['check','presentation','engineering-posix','inventory','full-quality','independent-review'].map(context=>({context,integration_id:context==='independent-review'?null:15368}))}},
   {type:'pull_request',parameters:{allowed_merge_methods:['squash'],required_review_thread_resolution:true}},
   {type:'required_linear_history'}]};
 const artifact={id:42,name:'quality-7-1-check',expired:false,workflow_run:{id:7,head_sha:head}};
 const checkout={schemaVersion:1,event:'merge_group',runId:7,attempt:1,tested:head,head,base,parents:[base]};
 const pr={number:510,node_id:'PR_510',state:'open',merged:false,draft:false,head:{sha:prHead,repo:{id:1429751262,full_name:repo}},
  base:{sha:base,ref:'develop',repo:{id:1429751262,full_name:repo}},labels:[],body:'Depends-on: none'};
 const review={id:90,context:'independent-review',state:'success',description:`Independent review test [base:${base}]`};
 const entry={id:'ENTRY_510',position:1,state:'AWAITING_CHECKS',baseCommit:{oid:base},headCommit:{oid:head},
  pullRequest:{number:510,headRefOid:prHead,baseRefName:'develop',isDraft:false,state:'OPEN',mergeQueueEntry:{id:'ENTRY_510'}}};
 const repository={databaseId:1429751262,nameWithOwner:repo,ref:{target:{oid:base}},
  mergeQueue:{entries:{nodes:[entry],pageInfo:{hasNextPage:false}}}};
 return {env,event,run,needs,jobs,ruleset,artifact,checkout,pr,review,entry,repository};
}
export function admissionQuery(f,writes=[]){
 return (...args)=>{
  const url=args.find(a=>typeof a==='string'&&a.startsWith('repos/'))??'';
  if(args[0]==='api'&&args[1]==='graphql')return JSON.stringify({data:{repository:f.repository}});
  if(args.includes('POST')){
   const state=args.find(a=>a.startsWith('state=')).slice(6),context=args.find(a=>a.startsWith('context=')).slice(8);
   writes.push({state,context});return JSON.stringify({state,context});
  }
  if(args[0]==='run'&&args[1]==='download'){
   writeFileSync(join(args[args.indexOf('--dir')+1],'ci-checkout.json'),JSON.stringify(f.checkout));return '';
  }
  if(url.endsWith('/rulesets/25870651'))return JSON.stringify(f.ruleset);
  if(url.endsWith('/actions/runs/7'))return JSON.stringify(f.run);
  if(url.includes('/actions/workflows/'))return JSON.stringify([{workflow_runs:[f.run]}]);
  if(url.includes('/actions/runs/7/jobs?'))return JSON.stringify([{jobs:f.jobs}]);
  if(url.includes('/artifacts?'))return JSON.stringify([{artifacts:[f.artifact]}]);
  if(url.endsWith('/actions/artifacts/42'))return JSON.stringify(f.artifact);
  if(url.endsWith('/pulls/510'))return JSON.stringify(f.pr);
  if(url.endsWith('/commits/'+f.env.GITHUB_SHA))return JSON.stringify({sha:f.env.GITHUB_SHA,parents:[{sha:f.event.merge_group.base_sha}]});
  if(url.includes(`/commits/${f.pr.head.sha}/statuses?`))return JSON.stringify([[f.review]]);
  if(url.endsWith('/git/ref/heads/'+f.env.GITHUB_REF.slice('refs/heads/'.length)))
   return JSON.stringify({ref:f.env.GITHUB_REF,object:{type:'commit',sha:f.env.GITHUB_SHA}});
  if(url.endsWith('/pulls/999'))return JSON.stringify({number:999,merged:false});
  throw Error('Unexpected query: '+args.join(' '));
 };
}
