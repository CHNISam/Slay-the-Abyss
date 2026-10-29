import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preservedUiLayer,requirePreservedUiSource,prePreservedUiSource,materializeBeforePreservedUi} from './helpers/pr323-preserved-ui-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
test('eleven complete preservation inputs recover exact 807 source and reject all drift',()=>{
 assert.equal(preservedUiLayer.baseline,'807df075f00a8f8531a896181d9ccdc08b0925fc');
 assert.equal(Object.keys(preservedUiLayer.files).length,11);
 const added=new Set(['config/luacheck-baseline.json','tests/lua/support/game_ui_fixture.lua','tests/lua/native_cursor_fields.lua']);
 const originalEight=Object.fromEntries(Object.entries(preservedUiLayer.files).filter(([path])=>!added.has(path)));
 assert.equal(hash(JSON.stringify(originalEight)),'fb783673c522babe50cf83a13923b78bf8fc508d8ff761184d6131633eb92224','all original eight before/after records remain immutable');
 for(const[path,binding]of Object.entries(preservedUiLayer.files)){
  const current=readFileSync(path,'utf8').replaceAll('\r\n','\n');requirePreservedUiSource(path,current);
  assert.equal(hash(binding.beforeSource),binding.beforeSha256);
  assert.equal(prePreservedUiSource(path,current),binding.beforeSource);
  assert.equal(prePreservedUiSource(path,current.replaceAll('\n','\r\n')),binding.beforeSource);
  assert.equal(prePreservedUiSource(path,binding.beforeSource),binding.beforeSource);
  for(const changed of [current+'\n-- drift\n',current.slice(1),current+current]){
   assert.throws(()=>requirePreservedUiSource(path,changed),/unreviewed preservation source drift/);
   assert.equal(prePreservedUiSource(path,changed),changed.replaceAll('\r\n','\n'),'unknown identities reach older guards with canonical line endings');
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
test('Windows CRLF valid and unknown-drift inputs normalize once without hiding source changes',()=>{
 for(const[path,binding]of Object.entries(preservedUiLayer.files)){
  const lf=readFileSync(path,'utf8').replaceAll('\r\n','\n'),crlf=lf.replaceAll('\n','\r\n');
  requirePreservedUiSource(path,crlf);
  assert.equal(prePreservedUiSource(path,crlf),binding.beforeSource);
  for(const drift of [lf+'\n-- unknown Windows drift\n',lf.slice(1),lf+lf]){
   const windows=drift.replaceAll('\n','\r\n');
   assert.throws(()=>requirePreservedUiSource(path,windows),/unreviewed preservation source drift/);
   assert.equal(prePreservedUiSource(path,windows),drift);
  }
 }
});
