// Real FS tracing in a child process: no global fs replacement or reader cache.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createTracing} from 'node:trace_events';
import {withHistoricalBaseline} from './historical-baseline-inputs.mjs';
import {normalizePr323CompositionSource,requirePr323Source} from './pr323-accepted-source-inverse.mjs';

const mode=process.argv[2];assert.ok(['foreign','equivalent','fresh-owner'].includes(mode));
withHistoricalBaseline(()=>{
 const path='config/architecture.json',live=readFileSync(path,'utf8'),equivalent=JSON.stringify(JSON.parse(live));
 const unknown=JSON.parse(live);unknown.unreviewed_token_probe=true;
 const foreign=JSON.stringify(unknown),trace=createTracing({categories:['node.fs.sync']});
 let changed=false;
 if(mode==='foreign'){
  trace.enable();assert.equal(normalizePr323CompositionSource(path,foreign),foreign);trace.disable();
 }else if(mode==='equivalent'){
  trace.enable();const normalized=normalizePr323CompositionSource(path,equivalent);trace.disable();
  assert.notEqual(normalized,equivalent,'token-equivalent source consumes the verified live spelling');
  requirePr323Source(path,equivalent);
 }else{
  requirePr323Source(path,equivalent);
  const owner='src/lua/abyss_battle_aim_arrow.lua',original=readFileSync(owner,'utf8');
  writeFileSync(owner,original+'\n-- actual linked owner drift\n');
  try{
   trace.enable();assert.throws(()=>requirePr323Source(path,equivalent),/unreviewed|linked/);trace.disable();changed=true;
  }finally{trace.disable();writeFileSync(owner,original);}
  requirePr323Source(path,equivalent);
 }
 process.stdout.write(JSON.stringify({mode,changed})+'\n');
});
