// Per-card local evidence only; never promotes platform or strict acceptance.
import { readFileSync,writeFileSync,mkdirSync,existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve,join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { runLua } from './test-lua.mjs';

const output=resolve(process.argv[2]??'.artifacts/warrior75-local');
if(existsSync(output)) throw Error('Use a new output directory to preserve evidence');
const hash=file=>createHash('sha256').update(readFileSync(file)).digest('hex');
const definitions=JSON.parse(readFileSync('data/cards.json','utf8')).cards.filter(c=>!['status','curse'].includes(c.type));
if(definitions.length!==75 || new Set(definitions.map(c=>c.id)).size!==75) throw Error('Exactly 75 distinct class cards are required');
const source=spawnSync('git',['rev-parse','HEAD'],{encoding:'utf8'});
if(source.status!==0) throw Error(source.stderr);
mkdirSync(output,{recursive:true});
const report={schemaVersion:1,at:new Date().toISOString(),sourceSha:source.stdout.trim(),
  boundary:'Local Lua execution and fixture acquisition; no original-PC or platform acceptance',
  inputs:{'data/cards.json':hash('data/cards.json')},suites:[],cards:[],ok:false};
for(const name of ['warrior75','warrior75_edges','warrior75_shuffle','warrior75_acquisition','warrior75_channels','warrior75_choice_ui','warrior75_card_text']){
  const file=`tests/lua/${name}.lua`;
  const row={file,sha256:hash(file),passed:false};
  report.suites.push(row);
  try{
    const r=runLua(file);row.status=r.status;row.passed=r.status===0;
    row.stdout=r.stdout;row.stderr=r.stderr;
  }catch(e){row.error=e.message;}
  console.log(`${row.passed?'PASS':'FAIL'} ${file}`);
}
const execution=report.suites[0],channels=report.suites[4];
for(const c of definitions){
  const base=execution.passed&&execution.stdout.includes(`- ${c.id} independent ordinary execution\n`);
  const upgraded=execution.passed&&execution.stdout.includes(`- ${c.id}+ independent ordinary execution\n`);
  const acquisition=channels.passed&&channels.stdout.includes(`- ${c.id} public acquisition / camp / next battle\n`);
  report.cards.push({id:c.id,base,upgraded,acquisition,platform:'pending',strictAcceptance:'pending'});
}
report.ok=report.suites.every(s=>s.passed)&&report.cards.every(c=>c.base&&c.upgraded&&c.acquisition);
writeFileSync(join(output,'results.json'),JSON.stringify(report,null,2)+'\n');
console.log(`75-card local evidence ${report.ok?'passed':'FAILED'}: ${join(output,'results.json')}`);
process.exitCode=report.ok?0:1;
