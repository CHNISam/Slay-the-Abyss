import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {betaSources,preBetaSource,prepareBetaRetirement} from './helpers/beta-integration-source.mjs';
import {prepareBattleLifeModuleRetirement} from './helpers/battle-life-source-inverse.mjs';
import {preDeckBrowseSource} from './helpers/deck-browse-source-inverse.mjs';
const hash=s=>s===null?null:createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('beta composition retains both complete source targets and immutable prior witnesses',()=>{
 for(const [path,binding]of Object.entries(betaSources)){
  const current=preDeckBrowseSource(path,readFileSync(path,'utf8')).replaceAll('\r\n','\n');assert.equal(hash(current),binding.sha256,path);
  for(const [target,destination]of Object.entries(binding.targets)){
   const prior=preBetaSource(path,current,target);
   assert.equal(hash(prior),destination.sha256,path+' '+target);
   assert.equal(preBetaSource(path,current.replaceAll('\n','\r\n'),target),prior);
   assert.equal(preBetaSource(path,prior,target),prior,'target remains idempotent');
   for(const unknown of [current+'\n-- unknown\n',current.slice(1),current+current])
    assert.equal(preBetaSource(path,unknown,target),unknown,'unknown whole source never acquires permission');
  }
 }
 assert.equal(hash(readFileSync('tests/fixtures/pr372-integration-sources.json','utf8')),'ea2f161779f99bc4f81c25c9087eeeb911951d52b5ff85bafec112b4c9e00995');
 assert.equal(hash(readFileSync('tests/fixtures/art-feature-source-layer.json','utf8')),'b2bef34f482a5eca07b74a10d5ca31f04a5256a6b3a3d249ff8597a7b5962a30');
});
test('recognized beta hosts validate every added owner on every invocation',()=>{
 const path='config/architecture.json',current=readFileSync(path,'utf8');
 const added=Object.keys(betaSources).filter(p=>betaSources[p].targets.history.absent);
 for(const changed of added){
  for(let i=0;i<2;i++)assert.throws(()=>preBetaSource(path,current,'history',{
   readSource:p=>readFileSync(p,'utf8')+(p===changed?'\n-- drift\n':'')
  }),/unreviewed beta linked owner/);
 }
});
test('beta retirement checks all owners twice and never deletes partially',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-beta-retirement-'));
 const paths=Object.keys(betaSources).filter(p=>betaSources[p].targets.history.absent);
 const put=(p,s)=>{mkdirSync(dirname(join(directory,p)),{recursive:true});writeFileSync(join(directory,p),s);};
 try{
  for(const p of paths)put(p,readFileSync(p,'utf8'));
  const retire=prepareBetaRetirement(directory);
  for(const changed of paths){
   put(changed,readFileSync(changed,'utf8')+'\n-- drift\n');
   assert.throws(retire,/unreviewed beta added module destination/);
   for(const p of paths)assert.ok(existsSync(join(directory,p)));
   put(changed,readFileSync(changed,'utf8'));
  }
  retire();for(const p of paths){assert.ok(!existsSync(join(directory,p)));assert.ok(existsSync(p));}
  assert.throws(()=>prepareBetaRetirement(process.cwd()),/historical copy/);
  assert.throws(()=>prepareBetaRetirement(process.cwd(),{sourceRoot:directory}),/historical copy/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('outer retirement refuses changed beta owners before deleting an older source owner',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-beta-outer-retirement-'));
 const old='src/lua/abyss_combat_catalog.lua';
 const paths=[old,...Object.keys(betaSources).filter(p=>betaSources[p].targets.history.absent)];
 const put=(p,s)=>{mkdirSync(dirname(join(directory,p)),{recursive:true});writeFileSync(join(directory,p),s);};
 try{
  for(const p of paths)put(p,readFileSync(p,'utf8'));
  const retire=prepareBattleLifeModuleRetirement(directory);
  const changed='scripts/official-vista-layout.mjs';put(changed,readFileSync(changed,'utf8')+'\n// drift\n');
  assert.throws(retire,/unreviewed .* (?:added )?module destination/);
  for(const p of paths)assert.ok(existsSync(join(directory,p)),'all source owners survive: '+p);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
