// Reproducible bounded, offline normal-rule runs; never rewrites game state.
import {runLua} from './test-lua.mjs';
import {writeFileSync,readFileSync,mkdirSync,unlinkSync} from 'node:fs';
import {gzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {gitSourceIdentity} from './release-notes.mjs';
const seeds=process.argv.slice(2).length?process.argv.slice(2).map(Number):[2,3,42,75,505];
if(seeds.some(x=>!Number.isSafeInteger(x)||x<0)||seeds.length>20)throw Error('1–20 integer seeds required');
const directory='docs/evidence/m3-normal-campaign-20261031';mkdirSync(directory,{recursive:true});
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const source=gitSourceIdentity();
if(!source.sourceCommit||source.sourceDirty)throw Error('Normal-rule evidence requires an exact clean source commit');
const report={kind:'offline-normal-rule-campaign',platformVerified:false,dataModified:false,
 ...source,startedAt:new Date().toISOString(),
 policy:'warrior75-visible-state-v1',policySha256:hash('scripts/warrior75-autoplay-policy.lua'),driverSha256:hash('scripts/m3-normal-campaign.lua'),eventCardPolicySha256:hash('scripts/m3-event-card-policy.lua'),resetVerificationKind:'fresh-Run-construction-only; not Host restart',runs:[]};
for(const seed of seeds){
 const temporary=`build/m3-normal-${seed}.lua`;
 writeFileSync(temporary,`M3_SEED=${seed}\ndofile('scripts/m3-normal-campaign.lua')\n`);
 let result;try{result=runLua(temporary,{timeout:300000,maxBuffer:50000000});}finally{unlinkSync(temporary);}
 if(result.status!==0)throw Error(result.stderr||result.stdout);
 const line=result.stdout.split('\n').find(x=>x.startsWith('M3_EVIDENCE_JSON '));if(!line)throw Error('missing evidence');
 const evidence={...JSON.parse(line.slice(17)),...source,driverSha256:report.driverSha256,
  policySha256:report.policySha256,eventCardPolicySha256:report.eventCardPolicySha256};
 const artifact=`seed-${seed}.json.gz`;writeFileSync(`${directory}/${artifact}`,gzipSync(JSON.stringify(evidence)));
 const row={seed,status:evidence.status,reason:evidence.reason,floor:evidence.final.floor,hp:evidence.final.hp,
 ending:evidence.final.ending,actions:evidence.actions.length,newRunConstructionResetVerified:evidence.newRunConstructionResetVerified,artifact};
 report.runs.push(row);console.log(JSON.stringify(row));
 writeFileSync(`${directory}/summary.json`,JSON.stringify(report,null,2)+'\n');
}
