import {preTextSafetySource, textSafetyCorrection} from './helpers/ci-text-safety-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preFiveRunnerSource as pre,fiveRunnerSourceProof as proof,fiveRunnerSourcePaths as paths} from './helpers/five-runner-source.mjs';
import {preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
const norm=s=>s.replaceAll('\r\n','\n'),read=p=>readFileSync(p,'utf8');
const projections=[(p,s,o)=>pre(p,s,o),(p,s,o)=>preDeliveryTargetSource(p,s,'legacyM3',o),(p,s,o)=>preIntegrationSource(p,s,'base',o)];
test('five Linux runner sources exactly retreat to their fixed parent without changing old proof',()=>{
 for(const p of paths){const live=norm(read(p)),prior=pre(p,live);
  assert.equal(createHash('sha256').update(prior).digest('hex'),proof.files[p].beforeSha256);
  assert.equal(pre(p,live.replaceAll('\n','\r\n')),prior);
  for(const project of projections)assert.equal(project(p,live,{readSource:read}),project(p,prior,{readSource:read}));
  for(const bad of [live+' ',live.slice(1),live.replace(/\S/,'X'),live+'😀'])assert.equal(pre(p,bad),bad);
  assert.equal(pre('wrong/'+p,live),live);
 }
});
test('both runner owners remain fresh under every caller-owned historical bridge after warming',()=>{
 for(const p of paths)for(const project of projections){
  const live=norm(read(p));let mutationPath,mutation,reads=0;
  const readSource=q=>{reads++;return q===mutationPath?mutation:read(q);};
  project(p,live,{readSource});const warm=reads;assert(warm>0);
  for(const owner of paths)for(const bad of [norm(read(owner))+' ',norm(read(owner)).replace(/\S/,'X'),undefined]){
   mutationPath=owner;mutation=bad;assert.throws(()=>project(p,live,{readSource}),/linked source/);
  }
  assert(reads>warm);mutationPath=undefined;project(p,live,{readSource});
  for(const owner of paths)assert.throws(()=>project(p,live,{readSource:q=>{if(q===owner)throw Error('missing');return read(q);}}),/linked source/);
 }
});


test('the admission correction accepts only its complete exact parent and frozen witness',()=>{
 const p='scripts/ci-test-timings.json',raw=read(p),before=preTextSafetySource(p,raw);
 assert.equal(createHash('sha256').update(before).digest('hex'),textSafetyCorrection.parentSha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0').update(before).digest('hex'),textSafetyCorrection.parentGitBlob);
 assert.ok(Object.isFrozen(textSafetyCorrection));
 for(const key of Object.keys(textSafetyCorrection))assert.throws(()=>{textSafetyCorrection[key]='drift';},TypeError);
 assert.equal(preTextSafetySource(p,before),before);
 assert.equal(preTextSafetySource(p,raw.replaceAll('\n','\r\n')),before);
 assert.equal(preTextSafetySource('wrong/'+p,raw),raw);
 for(const mutate of [
  d=>{d.lua[textSafetyCorrection.file]=29999;},
  d=>{d.lua[textSafetyCorrection.file]=1829;},
  d=>{d.lua['tests/lua/presentation_responsibilities_trace.lua']=9999;},
  d=>{d.source.description=textSafetyCorrection.beforeDescription;},
  d=>{d.initialMs.linux.pop();},
  d=>{d.initialMs.win32[0]++;},
  d=>{d.luaShard[textSafetyCorrection.file]++;},
 ]){
  const value=JSON.parse(raw);mutate(value);const bad=JSON.stringify(value,null,2)+'\n';
  assert.equal(preTextSafetySource(p,bad),bad);
  assert.equal(pre(p,bad),bad);
  for(const project of projections)assert.throws(()=>project('scripts/verify-delivery.mjs',read('scripts/verify-delivery.mjs'),{readSource:q=>q===p?bad:read(q)}),/linked source/);
 }
 for(const bad of [null,undefined,'',raw+' ',raw.slice(1)])assert.equal(preTextSafetySource(p,bad),bad);
});
