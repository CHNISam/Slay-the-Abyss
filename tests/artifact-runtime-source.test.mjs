import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {artifactRuntimeProof as proof,preArtifactRuntimeSource as project,artifactRuntimePaths} from './helpers/artifact-runtime-source.mjs';
import {preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';
const read=p=>readFileSync(p,'utf8'),hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('all four exact Artifact runtime repairs retreat to untouched prior b035 identities without accepting foreign bytes',()=>{
 for(const[p,b]of Object.entries(proof.files)){
  const source=read(p),before=project(p,source);
  assert.equal(hash(source),b.afterSha256);assert.equal(hash(before),b.beforeSha256);
  assert.equal(project(p,before),before);assert.equal(project(p,source.replaceAll('\n','\r\n')),before);
  assert.equal(project('wrong/path',source),source);assert.equal(project(p,null),null);
  for(const bad of [source+'\n',source.slice(1),source+source])assert.equal(project(p,bad),bad);
  for(const h of b.hunks){
   for(const replacement of [[],h.before,[...h.after,...h.after],['-- foreign']]){
    const lines=source.replaceAll('\r\n','\n').split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');
    if(bad!==source)assert.equal(project(p,bad),bad);
   }
  }
 }
});
test('warm direct and outer projections re-read caller-owned repairs before every source permission',()=>{
 for(const p of artifactRuntimePaths){
  const source=read(p);project(p,source);preDeliveryTargetSource(p,source,'developEvents');
  for(const q of artifactRuntimePaths)for(const bad of [undefined,read(q)+'\n-- drift']){
   const readSource=r=>r===q?bad:read(r);
   assert.throws(()=>project(p,source,{readSource}),/artifact linked source/);
   assert.throws(()=>preDeliveryTargetSource(p,source,'developEvents',{readSource}),/artifact linked source/);
  }
 }
});
