import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
function git(...args) {
  const r=spawnSync('git',args,{encoding:'utf8',timeout:10000});if(r.error||r.status!==0)throw new Error(r.error?.message||r.stderr);return r.stdout.trim();
}
const event=JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH,'utf8')),tested=git('rev-parse','HEAD');
if(tested!==process.env.GITHUB_SHA)throw new Error('CI checkout SHA mismatch');
const receipt={schemaVersion:1,event:process.env.GITHUB_EVENT_NAME,runId:Number(process.env.GITHUB_RUN_ID),attempt:Number(process.env.GITHUB_RUN_ATTEMPT),
  tested,head:event.pull_request?.head.sha??tested,base:event.pull_request?.base.sha??event.before,
  prNumber:event.pull_request?.number,parents:git('show','-s','--format=%P','HEAD').split(' ')};
mkdirSync('build',{recursive:true});writeFileSync('build/ci-checkout.json',JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(receipt));
