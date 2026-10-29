import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preservedUiLayer,requirePreservedUiSource,prePreservedUiSource,materializeBeforePreservedUi} from './helpers/pr323-preserved-ui-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
test('eight complete preservation inputs recover exact 807 source and reject all drift',()=>{
 assert.equal(preservedUiLayer.baseline,'807df075f00a8f8531a896181d9ccdc08b0925fc');
 assert.equal(Object.keys(preservedUiLayer.files).length,8);
 for(const[path,binding]of Object.entries(preservedUiLayer.files)){
  const current=readFileSync(path,'utf8');requirePreservedUiSource(path,current);
  assert.equal(hash(binding.beforeSource),binding.beforeSha256);
  assert.equal(prePreservedUiSource(path,current),binding.beforeSource);
  assert.equal(prePreservedUiSource(path,current.replaceAll('\n','\r\n')),binding.beforeSource);
  assert.equal(prePreservedUiSource(path,binding.beforeSource),binding.beforeSource);
  for(const changed of [current+'\n-- drift\n',current.slice(1),current+current]){
   assert.throws(()=>requirePreservedUiSource(path,changed),/unreviewed preservation source drift/);
   assert.equal(prePreservedUiSource(path,changed),changed,'unknown identities must reach older guards unchanged');
  }
 }
});
test('historical materialization restores every complete source input before older replay',()=>{
 const directory=mkdtempSync(join(tmpdir(),'pr323-preserved-ui-'));
 try{
  for(const path of Object.keys(preservedUiLayer.files)){
   const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  materializeBeforePreservedUi(directory);
  for(const[path,binding]of Object.entries(preservedUiLayer.files))assert.equal(readFileSync(join(directory,path),'utf8'),binding.beforeSource,path);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
