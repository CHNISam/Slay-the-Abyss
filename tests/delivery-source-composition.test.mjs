import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {deliverySourceProof as proof,preDeliveryTargetSource as project,preDeliverySource,preLegacyMultiSource,verifiedDeliverySources,materializeBeforeDelivery} from './helpers/delivery-source-composition.mjs';
import {preMultiMonsterArtSource} from './helpers/multi-monster-art-source-inverse.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const hash=s=>s===null?null:createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
const source=(p,target)=>target==='develop'?project(p,read(p),'developEvents'):target==='pre379'?preDeliverySource(p,read(p)):read(p);
const put=(root,p,s)=>{mkdirSync(dirname(join(root,p)),{recursive:true});writeFileSync(join(root,p),s);};
test('all exact final and independent historical arrows reconstruct full Git-bound identities',()=>{
 assert.equal(proof.targets.developEvents.afterCommit,'9c2067547cb378fb33827f63d54cf6394ef32f12');
 assert.equal(proof.targets.develop.beforeCommit,'ef7b3e80093dd737be5496627250269532da001c');
 assert.equal(proof.targets.developEvents.beforeCommit,proof.targets.develop.afterCommit);
 assert.equal(proof.targets.legacyM3.beforeCommit,'b990b70b4bb1684858c4a9b22820798c84df8ef3');
 for(const [target,{files}]of Object.entries(proof.targets))for(const [p,b]of Object.entries(files)){
  const live=source(p,target);assert.equal(hash(live),b.afterSha256,p+' '+target);
  const old=project(p,live,target);assert.equal(hash(old),b.beforeSha256);
  assert.equal(project(p,live.replaceAll('\n','\r\n'),target),old);
  assert.equal(project(p,old,target),old);
 }
});
test('unknown, partial, duplicated, reordered and foreign bytes retain every strict boundary',()=>{
 for(const [target,{files}]of Object.entries(proof.targets))for(const p of Object.keys(files)){
  const live=source(p,target),lines=live.split('\n'),i=lines.findIndex((s,i)=>s&&lines[i+1]&&s!==lines[i+1]);
  const swapped=i>=0?[...lines]:[...live];const at=i>=0?i:swapped.findIndex((c,j)=>swapped[j+1]&&c!==swapped[j+1]);assert.ok(at>=0);[swapped[at],swapped[at+1]]=[swapped[at+1],swapped[at]];
  for(const bad of [live+'\n',live.slice(1),live+live,swapped.join(i>=0?'\n':'')]){assert.notEqual(bad,live);assert.equal(project(p,bad,target),bad);}
  assert.equal(project('unregistered/'+p,live,target),live);assert.equal(project(p,null,target),null);
 }
});
test('each recognized arrow rereads every newly added owner after a successful warm call',()=>{
 for(const [target,{files}]of Object.entries(proof.targets)){
  const host=Object.keys(files).find(p=>files[p].beforeSha256!==null);if(!host)continue;
  const live=source(host,target);
  for(const [linked,b]of Object.entries(files).filter(([,b])=>b.beforeSha256===null)){
   let bad=false,count=0;const readSource=p=>{if(p===linked){count++;if(bad)return read(p)+'\n';}return read(p);};
   project(host,live,target,{readSource});assert.ok(count>0);bad=true;
   assert.throws(()=>project(host,live,target,{readSource}),/linked source/);
   assert.throws(()=>project(host,live,target,{readSource:p=>{if(p===linked)throw Error('missing');return read(p);}}),/linked source/);
  }
 }
});
test('complete canonical materialization restores the exact pre379 accepted closure, rejects unknown copies atomically, and never targets live root',()=>{
 const root=mkdtempSync(join(tmpdir(),'delivery-proof-'));
 try{
  const expected=verifiedDeliverySources('pre379');for(const [p]of expected)put(root,p,read(p));
  const [dirty]=expected.at(-1);put(root,dirty,read(dirty)+'\n');
  assert.throws(()=>materializeBeforeDelivery(root),/unreviewed integrated destination/);
  for(const [p]of expected.slice(0,-1))assert.equal(readFileSync(join(root,p),'utf8'),read(p),'no early writes');
  put(root,dirty,read(dirty));materializeBeforeDelivery(root);
  for(const [p,before]of expected){if(before===null)assert.equal(existsSync(join(root,p)),false);else assert.equal(readFileSync(join(root,p),'utf8'),before);}
  materializeBeforeDelivery(root);assert.throws(()=>materializeBeforeDelivery(process.cwd()),/separate historical/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('the separate accepted schema2 native archive remains byte-exact and executable, not substituted for ef7 prototype',()=>{
 const bytes=read('tests/fixtures/native-monster-pre-ef7-source-layer.json');
 assert.equal(hash(bytes),'0b19ec26d75aaa399f74c8bf22f3eb451b79174699946ea2b525fcae72d99d2f');
 const old=JSON.parse(bytes);for(const [p,b]of Object.entries(old.files)){
  const prior=preMultiMonsterArtSource(p,preLegacyMultiSource(p,read(p)));assert.equal(hash(prior),b.afterSha256,p);
  if(b.beforeSha256!==null){const lines=prior.split('\n');for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}assert.equal(hash(lines.join('\n')),b.beforeSha256);}
 }
});
test('a drifted existing middle-layer source cannot be copied through or permit early retirement',()=>{
 const root=mkdtempSync(join(tmpdir(),'delivery-live-drift-')),sourceRoot=join(root,'live'),destination=join(root,'history');
 try{
  mkdirSync(destination);put(destination,'keep','untouched');
  for(const [p]of verifiedDeliverySources('pre379'))put(sourceRoot,p,read(p));
  const p='data/relics.json';put(sourceRoot,p,read(p)+'\n');
  assert.throws(()=>materializeBeforeDelivery(destination,{sourceRoot}),/unreviewed current/);
  assert.equal(readFileSync(join(destination,'keep'),'utf8'),'untouched');
 }finally{rmSync(root,{recursive:true,force:true});}
});
