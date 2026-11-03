// Explicit developer replay; normal tests do not require Git history.
import {execFileSync,spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,openSync,closeSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';

const revision=process.argv[2];
if(!revision||!/^[a-f0-9]{40}$/.test(revision))throw new Error('Usage: actor-damage-parity.mjs <exact baseline SHA>');
const file='src/lua/abyss_actor.lua',directory='build/actor-damage-parity';mkdirSync(directory,{recursive:true});
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(normalize(s)).digest('hex');
const before=execFileSync('git',['show',`${revision}:${file}`],{encoding:'utf8'}),after=readFileSync(file,'utf8');
writeFileSync(`${directory}/before.lua`,before);writeFileSync(`${directory}/after.lua`,after);
const cli=createRequire(import.meta.url).resolve('fengari-node-cli/src/lua-cli.js');
const fixtures=['actor_damage_pipeline','plated_armor_queue','fatal_hp_loss_callbacks','ending_damage_hooks','hp_loss_action_boundaries'];
const results=[];
for(const name of fixtures){
  const outputs=[];
  for(const version of ['before','after']){
    const path=resolve(directory,`${version}.lua`).replaceAll('\\','/');
    const driver=`${directory}/${name}-${version}.lua`,log=`${directory}/${name}-${version}.log`;
    writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_actor=dofile(${luaString(path)});dofile('tests/helpers/actor-damage-trace.lua');dofile('tests/lua/${name}.lua')`);
    const fd=openSync(log,'w');let result;
    try{result=spawnSync(process.execPath,[cli,'-e',`dofile(${luaString(resolve(driver).replaceAll('\\','/'))})`],{encoding:'utf8',timeout:30000,stdio:['ignore',fd,'pipe']});}
    finally{closeSync(fd);}
    if(result.error||result.status!==0)throw new Error(`${name}/${version}: ${result.error?.message??result.stderr}; inspect ${log}`);
    outputs.push(readFileSync(log,'utf8'));
  }
  if(outputs[0]!==outputs[1])throw new Error(`${name}: complete state/event/queue/RNG/identity output differs; inspect ${directory}`);
  const row={fixture:`tests/lua/${name}.lua`,identical:true,boundaries:outputs[0].split('\n').filter(line=>line.startsWith('DAMAGE_BOUNDARY ')).length,
    bytes:Buffer.byteLength(outputs[0]),traceSha256:hash(outputs[0])};
  results.push(row);console.log(`${name}: ${row.boundaries} equal boundaries, ${row.traceSha256}`);
}
writeFileSync(`${directory}/report.json`,JSON.stringify({schemaVersion:1,baselineRevision:revision,source:file,runtime:process.version,
  beforeSourceSha256:hash(before),afterSourceSha256:hash(after),fixtures:results,
  contract:'Complete return/state/event/reaction queue/RNG and graph aliases. Immutable catalog/rules/sourcePools/statusDefinitions omitted from trace only; public rollback separately verifies all original tables and values. Every fixture runs in independent old/new VMs under unchanged 30-second timeout; full output goes directly to disk.'},null,2)+'\n');
