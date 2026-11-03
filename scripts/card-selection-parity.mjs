// Developer evidence replay; ordinary tests do not depend on Git history.
import {execFileSync,spawnSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,openSync,closeSync} from 'node:fs';
import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {luaString} from './build-lua-data.mjs';

const revision=process.argv[2];
if(!revision||!/^[a-f0-9]{40}$/.test(revision))throw new Error('Usage: card-selection-parity.mjs <exact 40-character baseline SHA>');
const directory='build/selection-parity';mkdirSync(directory,{recursive:true});
const file='src/lua/abyss_card_actions.lua';
const baseline=execFileSync('git',['show',`${revision}:${file}`],{encoding:'utf8'});
const current=readFileSync(file,'utf8');
const hash=text=>createHash('sha256').update(text.replaceAll('\r\n','\n')).digest('hex');
writeFileSync(`${directory}/before.lua`,baseline);
writeFileSync(`${directory}/after.lua`,current);
const results=[];
const cli=createRequire(import.meta.url).resolve('fengari-node-cli/src/lua-cli.js');
for(const [name,fixture,flag] of [
  ['selection','tests/lua/card_selection_protocol.lua','ABYSS_SELECTION_TRACE'],
  ['registry','tests/lua/support/card_actions_registry_fixture.lua',null],
  ['exhaust','tests/lua/card_actions_exhaust.lua','ABYSS_EXHAUST_TRACE'],
]){
  const outputs=[];
  for(const version of ['before','after']){
    const module=resolve(directory,`${version}.lua`).replaceAll('\\','/');
    const driver=`${directory}/${name}-${version}.lua`;
    writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;${flag?`${flag}=true;`:''}package.loaded.abyss_card_actions=dofile(${luaString(module)});dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
    // Preserve every trace byte on disk instead of overflowing a pipe buffer.
    // The existing 30-second VM budget remains unchanged.
    const log=`${directory}/${name}-${version}.log`,fd=openSync(log,'w');
    let result;
    try{result=spawnSync(process.execPath,[cli,'-e',`dofile(${luaString(resolve(driver).replaceAll('\\','/'))})`],
      {encoding:'utf8',timeout:30000,stdio:['ignore',fd,'pipe']});}
    finally{closeSync(fd);}
    if(result.error||result.status!==0)throw new Error(`${name}/${version}: ${result.error?.message??result.stderr}; inspect ${log}`);
    outputs.push(readFileSync(log,'utf8'));
  }
  if(outputs[0]!==outputs[1])throw new Error(`${name}: complete state/return/event/identity trace differs; inspect ${directory}`);
  const row={fixture,identical:true,traceSha256:hash(outputs[0]),bytes:Buffer.byteLength(outputs[0]),
    boundaries:outputs[0].split('\n').filter(line=>/^(?:SELECTION_TRACE|EXHAUST_TRACE|REGISTRY|CHOICE|RETURN|VICTORY) /.test(line)).length};
  results.push(row);console.log(`${name}: ${row.boundaries} identical boundaries, ${row.traceSha256}`);
}
const report={schemaVersion:1,baselineRevision:revision,source:file,
  beforeSourceSha256:hash(baseline),afterSourceSha256:hash(current),runtime:process.version,
  fixtures:results,traceContract:'Complete mutable state and return values, stable graph aliases, events, RNG states, queues and choice tokens; only catalog/rules/sourcePools/statusDefinitions omitted from serialization. Rollback fixture separately checks every original table, including immutable directories.',
};
writeFileSync(`${directory}/report.json`,JSON.stringify(report,null,2)+'\n');
