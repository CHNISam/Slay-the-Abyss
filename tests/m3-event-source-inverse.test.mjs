import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync,existsSync,symlinkSync,linkSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {m3EventSourceLayer as proof,m3EventAddedPaths as added,preM3EventSource as project,prepareM3EventRetirement as prepare,materializeBeforeM3Events as materialize} from './helpers/m3-event-source-inverse.mjs';
import {preRelicRound3CompositionSource as round3} from './helpers/relic-round3-composition.mjs';
import {preRelicRound2CompositionSource as round2} from './helpers/relic-round2-composition.mjs';
import {preRelicArtCompositionSource as art} from './helpers/relic-art-composition.mjs';
import {requireEventProductionSource} from './helpers/event-production-source-inverse.mjs';
import {prepareBattleLifeModuleRetirement} from './helpers/battle-life-source-inverse.mjs';
const read=p=>readFileSync(p,'utf8');
const hash=s=>s===null?null:createHash('sha256').update(s).digest('hex');
const put=(dir,path,s)=>{mkdirSync(dirname(join(dir,path)),{recursive:true});writeFileSync(join(dir,path),s);};
const temp=()=>mkdtempSync(join(tmpdir(),'abyss-m3-source-'));
const live=Object.fromEntries(Object.keys(proof.files).map(p=>[p,read(p)]));

test('seven complete frozen M3 sources recover exact Git baseline, CRLF and absence identities',()=>{
 assert.equal(added.length,2);
 for(const [path,b]of Object.entries(proof.files)){
  assert.equal(hash(live[path]),b.afterSha256);
  const previous=project(path,live[path]);assert.equal(hash(previous),b.beforeSha256);
  if(previous!==null)assert.equal(previous,execFileSync('git',['show',proof.baseCommit+':'+path],{encoding:'utf8'}));
  assert.equal(project(path,live[path].replaceAll('\n','\r\n')),previous);
  assert.equal(project(path,previous),previous);assert.equal(project(path,undefined),undefined);
 }
 assert.equal(project('unknown','untouched'),'untouched');
});
test('unknown, partial, duplicate, moved and cross-path bytes never acquire M3 permission',()=>{
 for(const [path,b]of Object.entries(proof.files)){
  const current=live[path],lines=current.split('\n');
  const mutants=[current+'\n-- drift\n',current.slice(1),current+current,[...lines].reverse().join('\n'),live[Object.keys(live).find(p=>p!==path)]];
  for(const h of b.hunks){const partial=[...lines];partial.splice(h.at,h.after.length,...h.before);if(hash(partial.join('\n'))!==b.beforeSha256)mutants.push(partial.join('\n'));}
  for(const mutant of mutants){assert.equal(project(path,mutant),mutant);if(!added.includes(path))assert.throws(()=>requireEventProductionSource(path,mutant),/unreviewed/);}
 }
});
test('every recognized host requires both complete linked owners, including nonstrings and missing owners',()=>{
 for(const path of Object.keys(live))for(const changed of added){
  for(const value of [null,live[changed]+'\n'])assert.throws(()=>project(path,live[path],{readSource:p=>p===changed?value:live[p]}),/M3 linked source/);
  assert.throws(()=>project(path,live[path],{readSource:p=>{if(p===changed)throw Error('missing');return live[p];}}),/M3 linked source missing/);
 }
});
test('warm outer composition caches never bypass linked owner checks',()=>{
 // Read owners from an isolated cwd so no production file is ever mutated.
 const directory=temp(),cwd=process.cwd(),path='config/architecture.json';
 try{
  for(const p of added)put(directory,p,live[p]);process.chdir(directory);
  for(const fn of [round3,round2,art]){
   fn(path,live[path],'relic');
   for(const p of added){
    put(directory,p,live[p]+'\n-- drift');assert.throws(()=>fn(path,live[path],'relic'),/M3 linked source drift/);
    rmSync(join(directory,p));assert.throws(()=>fn(path,live[path],'relic'),/M3 linked source missing/);put(directory,p,live[p]);
   }
  }
 }finally{process.chdir(cwd);rmSync(directory,{recursive:true,force:true});}
});
test('materialization validates all destinations then restores exact baseline and retires only new owners',()=>{
 const directory=temp();try{
  for(const [p,s]of Object.entries(live))put(directory,p,s);put(directory,'keep','untouched');
  for(const p of Object.keys(live)){
   put(directory,p,live[p]+'\n-- drift');assert.throws(()=>materialize(directory),/unreviewed M3/);
   for(const q of Object.keys(live))assert.ok(existsSync(join(directory,q)),'no partial removal');
   for(const q of Object.keys(live).filter(q=>q!==p))assert.equal(read(join(directory,q)),live[q],'no partial write');put(directory,p,live[p]);
  }
  materialize(directory);
  for(const [p,b]of Object.entries(proof.files))if(b.beforeSha256===null)assert.equal(existsSync(join(directory,p)),false);else assert.equal(hash(read(join(directory,p))),b.beforeSha256);
  assert.equal(read(join(directory,'keep')),'untouched');materialize(directory);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('retirement rejects post-prepare drift, missing owners and same-byte inode retargeting atomically',()=>{
 const directory=temp();try{
  for(const p of added)put(directory,p,live[p]);
  for(const p of added){
   let retire=prepare(directory);put(directory,p,live[p]+'\n');assert.throws(retire,/unreviewed M3/);for(const q of added)assert.ok(existsSync(join(directory,q)));put(directory,p,live[p]);
   retire=prepare(directory);rmSync(join(directory,p));assert.throws(retire,/changed after preparation/);put(directory,p,live[p]);
   retire=prepare(directory);const alternate=join(directory,'alternate');writeFileSync(alternate,live[p]);rmSync(join(directory,p));symlinkSync(alternate,join(directory,p));assert.throws(retire,/regular file/);rmSync(join(directory,p));put(directory,p,live[p]);
  }
  prepare(directory)();for(const p of added)assert.equal(existsSync(join(directory,p)),false);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('live roots, aliases, escaping parents and hardlinks cannot be materialized or retired',()=>{
 const directory=mkdtempSync(join(process.cwd(),'build-m3-safety-'));try{
  assert.throws(()=>prepare(process.cwd()),/separate historical/);assert.throws(()=>materialize(process.cwd()),/separate historical/);
  const alias=join(directory,'alias');symlinkSync(process.cwd(),alias,'dir');assert.throws(()=>prepare(alias),/separate historical/);
  const copy=join(directory,'copy');mkdirSync(copy);symlinkSync(join(process.cwd(),'src'),join(copy,'src'),'dir');assert.throws(()=>prepare(copy),/escape|live source/);
  rmSync(join(copy,'src'));const p=added[0];mkdirSync(dirname(join(copy,p)),{recursive:true});linkSync(join(process.cwd(),p),join(copy,p));assert.throws(()=>materialize(copy),/live source hardlink/);
  for(const [p,s]of Object.entries(live))assert.equal(read(p),s);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('combined old retirement checks M3 owners before deleting any previous module',()=>{
 const directory=temp(),old='src/lua/abyss_combat_catalog.lua';try{
  for(const p of added)put(directory,p,live[p]);put(directory,old,read(old));const retire=prepareBattleLifeModuleRetirement(directory);
  put(directory,added[1],live[added[1]]+'\n');assert.throws(retire,/unreviewed M3/);for(const p of [...added,old])assert.ok(existsSync(join(directory,p)));
  put(directory,added[1],live[added[1]]);put(directory,old,read(old)+'\n');assert.throws(retire,/unreviewed catalog/);for(const p of [...added,old])assert.ok(existsSync(join(directory,p)));
 }finally{rmSync(directory,{recursive:true,force:true});}
});
