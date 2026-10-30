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
