import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preEvent487Source as inverse} from './helpers/event-487-source-inverse.mjs';
import {deliverySourceProof as proof,preDeliveryTargetSource as project,tryDeliverySource,verifiedDeliverySources} from './helpers/delivery-source-composition.mjs';
const path='src/lua/abyss_nloth_event.lua';
const current=readFileSync(new URL('../src/lua/abyss_nloth_event.lua',import.meta.url),'utf8').replaceAll('\r\n','\n');
const read=p=>p===path?current:readFileSync(p,'utf8');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('exact new event source reconstructs the immutable prior source and unknown bytes stay unknown',()=>{
 const old=inverse(path,current);
 assert.equal(hash(old),proof.targets.develop.files[path].afterSha256);
 assert.equal(inverse(path,current.replaceAll('\n','\r\n')),old);
 assert.equal(inverse(path,old),old);
 for(const bad of [current+'\n',current.slice(1),current+current])assert.equal(inverse(path,bad),bad);
 assert.equal(inverse('other',current),current);assert.equal(inverse(path,null),null);
});
test('recognized delivery source rereads current linked event and rejects subsequent drift',()=>{
 for(const target of ['develop','legacyMulti']){
  const files=proof.targets[target].files,host=Object.keys(files).find(p=>files[p].beforeSha256!==null);
  // For develop, project through its outer events layer before testing the inner target.
  let hostSource=read(host);if(target==='develop')hostSource=project(host,hostSource,'developEvents');
  let count=0,drift=false;const reader=p=>{if(p===path){count++;return read(p)+(drift?'\n':'');}return read(p);};
  project(host,hostSource,target,{readSource:reader});assert.ok(count>0);
  drift=true;assert.throws(()=>project(host,hostSource,target,{readSource:reader}),/delivery linked source identity/);assert.ok(count>1);
 }
});
test('verified historical closure projects exact current event and rejects drift',()=>{
 for(const target of ['develop','legacyMulti','pre379']){
  assert.equal(verifiedDeliverySources(target,{readSource:read}).find(([p])=>p===path)[1],null);
  assert.throws(()=>verifiedDeliverySources(target,{readSource:p=>read(p)+(p===path?'\n':'')}),/unreviewed current|delivery linked source identity/);
 }
});

test('direct and optional delivery entry points project the same exact current event',()=>{
 for(const target of ['develop','legacyMulti']){
  assert.equal(tryDeliverySource(path,current,target,{readSource:read}),null);
  assert.equal(project(path,current,target,{readSource:read}),null);
  const drift=current+'\n';
  assert.equal(tryDeliverySource(path,drift,target,{readSource:read}),undefined);
  assert.equal(project(path,drift,target,{readSource:read}),drift);
 }
});
