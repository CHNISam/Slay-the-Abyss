import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {dirname,resolve,join,basename} from 'node:path';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
const here=dirname(fileURLToPath(import.meta.url)),repo=resolve(here,'../../..');
const require=createRequire(import.meta.url),cli=require.resolve('fengari-node-cli/src/lua-cli.js');
for(const file of ['verify.lua','verify-production.lua','verify-scenes.lua']){
 const path=join(here,file).replaceAll('\\','/');
 let temporary,entry=`dofile(${JSON.stringify(path)})`;
 if(file==='verify-scenes.lua'){
  temporary=mkdtempSync(join(tmpdir(),'art-pressure-'));
  const exporters={AP_Control:'art/spikes/art-pressure/controller.lua',AP_A:'art/processed/ai-samples/lumine/A/asset.lua',AP_B2:'art/processed/ai-samples/lumine/B2/asset.lua',AP_Card:'art/spikes/card-capacity/reference/card.lua',AP_HighCard:'art/processed/ai-samples/starfall/B/card.lua'};
  const literal=s=>{let eq='=';while(s.includes(']'+eq+']'))eq+='=';return '['+eq+'[\n'+s+']'+eq+']';};
  const text='ARTPRESS_TEST_SOURCES={'+Object.entries(exporters).map(([name,p])=>`${name}=${literal(readFileSync(join(repo,p),'utf8'))}`).join(',\n')+'}\n'+entry;
  const prepared=join(temporary,'verify.lua');writeFileSync(prepared,text);
  entry=`dofile(${JSON.stringify(prepared.replaceAll('\\','/'))})`;
 }
 let r;
 try{r=spawnSync(process.execPath,[cli,'-e',entry],{cwd:repo,encoding:'utf8',timeout:60000,maxBuffer:2**20});}
 finally{if(temporary){
  if(dirname(resolve(temporary))!==resolve(tmpdir())||!basename(temporary).startsWith('art-pressure-'))throw Error('Unexpected temporary cleanup target');
  rmSync(temporary,{recursive:true,force:true});
 }}
 process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');
 if(r.error||r.status!==0||!r.stdout.includes('PASS '))throw Error(`${file} failed: ${r.error?.message||r.status}`);
}
