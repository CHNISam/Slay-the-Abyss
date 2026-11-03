import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,cpSync,mkdtempSync,rmSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preDeliveryTargetSource as project,tryDeliverySource,verifiedDeliverySources,materializeBeforeDelivery} from './helpers/delivery-source-composition.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
// Either PR can land first. Reconstruct the other exact reviewed current source
// from its immutable prior bytes; complete before/after hashes remain the oracle.
function currentEvent(id){
 const proof=JSON.parse(read(`tests/fixtures/event-${id}-source-inverse.json`));
 let source=read(proof.path);
 if(hash(source)===proof.beforeSha256){
  const lines=source.split('\n');
  for(const h of [...proof.hunks].reverse()){
   assert.deepEqual(lines.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);
   lines.splice(h.beforeAt,h.before.length,...h.after);
  }
  source=lines.join('\n');
 }
 assert.equal(hash(source),proof.afterSha256,'exact reviewed combined current event');
 return [proof.path,source];
}
for(const target of ['develop','legacyMulti','pre379'])test(`combined events preserve ${target} identities and fresh linked drift rejection`,()=>{
 const events=new Map([currentEvent(487),currentEvent(488)]),paths=[...events.keys()];
 let drift=new Set();const reader=p=>(events.get(p)??read(p))+(drift.has(p)?'\n':'');
 if(target!=='pre379')for(const [path,source]of events){
  for(const entry of [project,tryDeliverySource])assert.equal(entry(path,source,target,{readSource:reader}),null);
 }
 const expected=verifiedDeliverySources(target,{readSource:reader});
 for(const path of paths)assert.equal(expected.find(([p])=>p===path)[1],null);
 for(const changed of [[paths[0]],[paths[1]],paths]){
  drift=new Set(changed);
  assert.throws(()=>verifiedDeliverySources(target,{readSource:reader}),/unreviewed current|delivery linked source identity/);
  // Warm pure projections must not hide the second call's changed owner.
  if(target!=='pre379')for(const [path,source]of events)for(const entry of [project,tryDeliverySource])
   assert.throws(()=>entry(path,source,target,{readSource:reader}),/delivery linked source identity/);
  drift=new Set();assert.deepEqual(verifiedDeliverySources(target,{readSource:reader}),expected);
 }
});
test('materialization accepts both exact current events and rejects unknown destination bytes before writing',()=>{
 const root=mkdtempSync(join(tmpdir(),'event-source-materialize-'));
 try{
  const live=join(root,'live'),destination=join(root,'prior');
  // Source-only isolation; no mutable live tree is reused as a destination.
  cpSync('src',join(live,'src'),{recursive:true});
  cpSync('tests',join(live,'tests'),{recursive:true});
  for(const dir of ['config','scripts','data','tools'])cpSync(dir,join(live,dir),{recursive:true});
  const events=[currentEvent(487),currentEvent(488)];
  for(const [path,source]of events)writeFileSync(join(live,path),source);
  cpSync(live,destination,{recursive:true});
  const [path,source]=events[0];writeFileSync(join(destination,path),source+'\n');
  assert.throws(()=>materializeBeforeDelivery(destination,{sourceRoot:live}),/unreviewed integrated destination/);
  assert.equal(readFileSync(join(destination,events[1][0]),'utf8'),events[1][1],'failed validation must not partially write');
  writeFileSync(join(destination,path),source);materializeBeforeDelivery(destination,{sourceRoot:live});
  for(const [path]of events)assert.throws(()=>readFileSync(join(destination,path)),/ENOENT/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
