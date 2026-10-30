import {preDeckVisibilitySource} from './helpers/deck-visibility-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deckDeliveryProof as proof,deckDeliveryPaths,preDeckDeliverySource as project} from './helpers/deck-delivery-source-composition.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('all seven current merged sources recover the exact delivery and independent M4 identities',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const [path,b]of Object.entries(files)){
  const source=read(path);assert.equal(hash(preDeckVisibilitySource(path,source)),b.afterSha256);
  const before=project(path,source,target);assert.equal(hash(before),b.beforeSha256);
  assert.equal(project(path,source.replaceAll('\n','\r\n'),target),before);assert.equal(project(path,before,target),before);
 }
});
test('partial duplicated moved foreign or missing source cannot borrow either exact branch identity',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const path of Object.keys(files)){
  const source=read(path),lines=source.split('\n'),index=lines.findIndex((s,i)=>s&&lines[i+1]&&s!==lines[i+1]);assert.ok(index>=0);
  const swapped=[...lines];[swapped[index],swapped[index+1]]=[swapped[index+1],swapped[index]];
  for(const bad of [source+'\n',source.slice(1),source+source,swapped.join('\n')]){assert.notEqual(bad,source);assert.equal(project(path,bad,target),bad);}
  assert.equal(project('wrong/'+path,source,target),source);assert.equal(project(path,null,target),null);
 }
});
test('every integrated owner is reread after warm projections; absent drift and non-string owners reject',()=>{
 for(const target of Object.keys(proof.targets)){
  const host=Object.keys(proof.targets[target].files)[0],source=read(host);
  for(const linked of deckDeliveryPaths){
   let value=read(linked),calls=0;const readSource=p=>p===linked?(calls++,value):read(p);
   project(host,source,target,{readSource});assert.ok(calls>0);
   for(const bad of [null,undefined,value+'\n']){value=bad;assert.throws(()=>project(host,source,target,{readSource}),/linked source/);}
   assert.throws(()=>project(host,source,target,{readSource:p=>{if(p===linked)throw Error('missing');return read(p);}}),/linked source missing/);
  }
 }
});
