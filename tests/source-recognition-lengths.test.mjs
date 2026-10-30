import test from 'node:test';import assert from 'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{sourceRecognitionLengths as proof}from'./helpers/source-recognition-lengths.mjs';
import{preBetaHostSource}from'./helpers/beta-delivery-host-source.mjs';
import{preBetaSource}from'./helpers/beta-integration-source.mjs';
import{preAcceptedDevelopSource,preLegacyM3Source}from'./helpers/delivery-source-composition.mjs';
import{preIntegrationSource}from'./helpers/pr372-integration-source.mjs';
import{preNativeMonsterArtSource}from'./helpers/native-monster-art-source-inverse.mjs';
import{preM3EventDeliverySource}from'./helpers/m3-event-delivery-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex'),blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
const definitions=[
 ['beta',(p,s)=>preBetaHostSource(p,s),(p,s)=>preBetaSource(p,s)],
 ['pr372',(p,s)=>preAcceptedDevelopSource(p,s),(p,s)=>preIntegrationSource(p,s)],
 ['native',(p,s)=>preIntegrationSource(p,s,'monster'),preNativeMonsterArtSource],
 ['m3',preLegacyM3Source,preM3EventDeliverySource],
];
test('all 161 extra recognition lengths bind full fixed source SHA Git blob and UTF16 spelling',()=>{
 let count=0,unicode=0;
 for(const[name,prepare,project]of definitions)for(const[p,b]of Object.entries(proof.groups[name].files)){
  const source=normalize(prepare(p,readFileSync(p,'utf8')));count++;
  assert.equal(hash(source),b.sha256,name+' '+p);assert.equal(blob(source),b.gitBlob);assert.equal(source.length,b.utf16Length);
  if(Buffer.byteLength(source)!==source.length)unicode++;
  const before=project(p,source);assert.equal(project(p,source.replaceAll('\n','\r\n')),before);
 }
 assert.equal(count,161);assert.ok(unicode>0);assert.ok(Object.isFrozen(proof));
});
test('same-length Unicode and ASCII mutations are still rejected by original identities, not accepted by lengths',()=>{
 for(const[name,prepare,project]of definitions)for(const[p,b]of Object.entries(proof.groups[name].files)){
  const source=normalize(prepare(p,readFileSync(p,'utf8')));assert.ok(source.length>2);
  for(const bad of [(source[0]==='X'?'Y':'X')+source.slice(1),'界'+source.slice(1),'🙂'+source.slice(2),source+'\n',source.slice(1)]){
   assert.notEqual(bad,source);assert.equal(project(p,bad),bad,name+' '+p);
  }
 }
});
