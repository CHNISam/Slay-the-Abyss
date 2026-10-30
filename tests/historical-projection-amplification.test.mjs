import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';

test('foreign architecture tokens do not project an unrelated live owner graph',()=>{
 const script=`
 import fs from 'node:fs';
 import {syncBuiltinESMExports} from 'node:module';
 const original=fs.readFileSync;let linkedReads=0;
 fs.readFileSync=function(path,...args){if(String(path).startsWith('src/lua/'))linkedReads++;return original(path,...args);};
 syncBuiltinESMExports();
 const {normalizePr323CompositionSource}=await import('./tests/helpers/pr323-accepted-source-inverse.mjs');
 const source=original('config/architecture.json','utf8').replace('"layers"','"foreign_layers"');
 linkedReads=0;
 const projected=normalizePr323CompositionSource('config/architecture.json',source);
 console.log(JSON.stringify({unchanged:projected===source,linkedReads}));`;
 const result=spawnSync(process.execPath,['--input-type=module','-e',script],{encoding:'utf8',timeout:20000});
 assert.equal(result.error,undefined,'bounded historical projection must finish');
 assert.equal(result.status,0,result.stderr);
 const actual=JSON.parse(result.stdout);
 assert.equal(actual.unchanged,true,'foreign tokens remain exposed to strict inner guards');
 assert.equal(actual.linkedReads,0,'unrelated live graph must not be projected before token eligibility');
});

test('existing length gates reject repeated foreign architecture bytes without hashing',()=>{
 const script=`
 import crypto from 'node:crypto';
 import {syncBuiltinESMExports} from 'node:module';
 import {readFileSync} from 'node:fs';
 const original=crypto.createHash;let hashes=0;
 crypto.createHash=function(...args){hashes++;return original(...args);};
 syncBuiltinESMExports();
 const {preIntegrationSource}=await import('./tests/helpers/pr372-integration-source.mjs');
 const source=readFileSync('config/architecture.json','utf8')+'foreign';
 hashes=0;let unchanged=true;
 for(let i=0;i<100;i++)unchanged&&=preIntegrationSource('config/architecture.json',source)===source;
 console.log(JSON.stringify({unchanged,hashes}));`;
 const result=spawnSync(process.execPath,['--input-type=module','-e',script],{encoding:'utf8',timeout:20000});
 assert.equal(result.error,undefined);assert.equal(result.status,0,result.stderr);
 const actual=JSON.parse(result.stdout);assert.equal(actual.unchanged,true);
 assert.equal(actual.hashes,0,'retain the existing immutable length rejection gates');
});

test('warm architecture dispatch retains caller-owned linked validation for each public target',async()=>{
 const {readFileSync}=await import('node:fs');
 const {preIntegrationSource}=await import('./helpers/pr372-integration-source.mjs');
 const {deliverySourceProof}=await import('./helpers/delivery-source-composition.mjs');
 const path='config/architecture.json',source=readFileSync(path,'utf8');
 const linked=Object.keys(deliverySourceProof.targets.developEvents.files)
  .find(p=>deliverySourceProof.targets.developEvents.files[p].beforeSha256===null);
 assert.ok(linked);
 for(const target of ['base','monster','feature379']){
  let mode='good',reads=0;
  const readSource=p=>{
   if(p===linked){reads++;if(mode==='missing')throw Error('missing');}
   const text=readFileSync(p,'utf8');
   return p===linked&&mode==='drift'?text+'\n-- drift':text;
  };
  const prior=preIntegrationSource(path,source,target,{readSource});
  assert.ok(reads>0);reads=0;
  assert.equal(preIntegrationSource(path,source.replaceAll('\n','\r\n'),target,{readSource}),prior);
  assert.ok(reads>0,'CRLF still validates owners');
  for(mode of ['drift','missing']){
   reads=0;
   assert.throws(()=>preIntegrationSource(path,source,target,{readSource}),/linked source/);
   assert.ok(reads>0,'warm digest must not bypass caller reads');
  }
  mode='good';
  assert.equal(preIntegrationSource(path,source,target,{readSource}),prior);
 }
});
