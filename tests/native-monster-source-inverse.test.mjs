import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,existsSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {nativeMonsterSourceLayer as layer,preNativeMonsterArtSource as pre,nativeMonsterAddedPaths,prepareNativeMonsterRetirement} from './helpers/native-monster-art-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('one-drawing historical inverse recovers exact complete parent sources only',()=>{
 for(const [path,binding]of Object.entries(layer.files)) {
  const live=preIntegrationSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'),'monster');assert.equal(hash(live),binding.afterSha256,path);
  const previous=pre(path,live);assert.equal(pre(path,live.replaceAll('\n','\r\n')),previous,'explicit native CRLF composition '+path);assert.equal(previous===null?null:hash(previous),binding.beforeSha256,path);
  for(const mutant of [live+'\n-- unrelated drift\n',live.slice(1),live+(path==='config/architecture.json'?' /* unrelated */':' '),live.replace(/nativeMonsterArt|monsterArt|monster-art|abyss_monster_art/,'unreviewedMonster')]) {
   if(mutant!==live)assert.equal(pre(path,mutant),mutant,'partial/foreign/extra source must remain visible '+path);
  }
  assert.equal(pre('wrong-path/'+path,live),live);
 }
});
test('historical retirement validates all exact new files before deleting only owned copy modules',()=>{
 const directory=mkdtempSync(join(tmpdir(),'native-monster-inverse-'));
 try {
  for(const path of nativeMonsterAddedPaths){mkdirSync(dirname(join(directory,path)),{recursive:true});writeFileSync(join(directory,path),readFileSync(path));}
  const unknown=join(directory,'unrelated.lua');writeFileSync(unknown,'return true');
  const bad=nativeMonsterAddedPaths.at(-1);writeFileSync(join(directory,bad),readFileSync(bad,'utf8')+'\n-- drift');
  assert.throws(()=>prepareNativeMonsterRetirement(directory),/unreviewed native monster/);
  for(const path of nativeMonsterAddedPaths)assert(existsSync(join(directory,path)));
  writeFileSync(join(directory,bad),readFileSync(bad));const retire=prepareNativeMonsterRetirement(directory);
  for(const path of nativeMonsterAddedPaths)assert(existsSync(join(directory,path)),'prepare must not mutate');
  retire();for(const path of nativeMonsterAddedPaths)assert(!existsSync(join(directory,path)));assert(existsSync(unknown));
  assert.throws(()=>prepareNativeMonsterRetirement(process.cwd()),/separate historical/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('recognized grass hosts re-read every linked owner and reject live drift, missing or non-string owners',()=>{
 const path='config/architecture.json',source=readFileSync(path,'utf8');
 for(const added of nativeMonsterAddedPaths){
  for(const changed of [undefined,null,'-- drift']){
   const readSource=key=>key===added?changed:readFileSync(key,'utf8');
   assert.throws(()=>pre(path,source,{readSource}),/native monster linked source/);
  }
  assert.throws(()=>pre(path,source,{readSource:key=>{if(key===added)throw Error('missing');return readFileSync(key,'utf8');}}),/linked source missing/);
 }
 assert.notEqual(pre(path,source),source,'valid original source recovers after failed reads');
});
