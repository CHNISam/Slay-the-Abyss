import {preRelicRound2CompositionSource} from './helpers/relic-round2-composition.mjs';
import {preRelicArtCompositionSource} from './helpers/relic-art-composition.mjs';
import {preRelicArtFeatureCompositionSource} from './helpers/relic-art-feature-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync,existsSync,symlinkSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {m3EventDeliveryProof as proof,m3EventAddedPaths,preM3EventDeliverySource as prior,requireM3EventDeliverySource as requireSource,materializeBeforeM3EventDelivery as materialize} from './helpers/m3-event-delivery-source-inverse.mjs';
import {preRelicRound3CompositionSource} from './helpers/relic-round3-composition.mjs';
const read=p=>readFileSync(p,'utf8');
const put=(root,p,s)=>{mkdirSync(dirname(join(root,p)),{recursive:true});writeFileSync(join(root,p),s);};
const hash=s=>s===null?null:createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('all 62 current inputs reconstruct exact accepted Git base with forward and blob checks',()=>{
 assert.equal(Object.keys(proof.files).length,62);
 for(const [p,b]of Object.entries(proof.files)){
  const live=read(p);assert.equal(hash(live),b.afterSha256,p+' frozen current source');
  const old=requireSource(p,live);assert.equal(hash(old),b.beforeSha256,p+' accepted complete Git base');
  assert.equal(requireSource(p,live),old,p);assert.equal(prior(p,live.replaceAll('\n','\r\n')),old,p+' CRLF');
  assert.equal(prior(p,old),old,p+' idempotent');
 }
});
test('partial, duplicate, reordered, cross-path and unrelated mutations never project',()=>{
 const entries=Object.keys(proof.files);
 for(const p of entries){
  const source=read(p),lines=source.split('\n');const i=lines.findIndex((s,i)=>s&&lines[i+1]&&s!==lines[i+1]);assert.ok(i>=0);
  const reordered=[...lines];[reordered[i],reordered[i+1]]=[reordered[i+1],reordered[i]];
  const deleted=[...lines];deleted.splice(i,1);const duplicate=[...lines];duplicate.splice(i,0,lines[i]);
  for(const s of [source+'\n',source.slice(1),reordered.join('\n'),deleted.join('\n'),duplicate.join('\n'),read(entries.find(q=>q!==p))]){
   assert.notEqual(s,source);assert.equal(prior(p,s),s);assert.throws(()=>requireSource(p,s),/M3 event/);
  }
  for(const s of [null,undefined,''])assert.throws(()=>requireSource(p,s),/M3 event/);
 }
 assert.equal(prior('unknown','abc'),'abc');
});
test('every linked new module is reread on every recognized host call; missing/drift reject',()=>{
 const p='config/architecture.json',host=read(p);
 for(const linked of m3EventAddedPaths){
  let mode='good',calls=0;
  const readSource=q=>{if(q===linked){calls++;if(mode==='missing')throw Error('absent');if(mode==='drift')return read(q)+'\n';}return read(q);};
  prior(p,host,{readSource});assert.ok(calls>0);
  mode='drift';assert.throws(()=>prior(p,host,{readSource}),/M3 event/);
  mode='missing';assert.throws(()=>prior(p,host,{readSource}),/M3 event/);
 }
 // Outer wrapper invokes the live layer outside its existing pure-string cache.
 const linked=m3EventAddedPaths[0],original=read(linked),cwd=process.cwd(),root=mkdtempSync(join(tmpdir(),'m3-linked-'));
 try{
  for(const q of m3EventAddedPaths)put(root,q,read(q));
  process.chdir(root);
  const projectors=[preRelicRound3CompositionSource,preRelicRound2CompositionSource,preRelicArtCompositionSource,preRelicArtFeatureCompositionSource];
  for(const project of projectors)project(p,host,'relic');
  writeFileSync(linked,original+'\n');
  for(const project of projectors)assert.throws(()=>project(p,host,'relic'),/M3 event/);
 }finally{process.chdir(cwd);rmSync(root,{recursive:true,force:true});}
});
test('historical materialization is exact, atomic on unknown targets and rejects live aliases',()=>{
 const root=mkdtempSync(join(tmpdir(),'m3-inverse-'));
 try{
  for(const p of Object.keys(proof.files))put(root,p,read(p));
  const p='src/lua/abyss_combat.lua',before=readFileSync(join(root,p),'utf8');
  put(root,p,before+'\n');assert.throws(()=>materialize(root),/unreviewed M3 destination/);
  for(const q of m3EventAddedPaths)assert.ok(existsSync(join(root,q)),'no deletion before complete validation');
  put(root,p,before);materialize(root);
  for(const [q,b]of Object.entries(proof.files)){
   if(b.beforeSha256===null)assert.equal(existsSync(join(root,q)),false);else assert.equal(hash(readFileSync(join(root,q),'utf8')),b.beforeSha256);
  }
  materialize(root);assert.throws(()=>materialize(process.cwd()),/separate/);
  const q=m3EventAddedPaths[0];symlinkSync(join(process.cwd(),q),join(root,q));assert.throws(()=>materialize(root),/inside copy|alias live/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('reviewed canonical-pool witness rejects the former split-owner implementation',()=>{
 const p='src/lua/abyss_event_card_sampling.lua',live=read(p);
 const stale=live.replace(' -- Match and Keep uses this same canonical act-wide owner.\n','')
  .replaceAll('run.colorlessCardPool','run.eventCardPools')
  .replace('{act=run.act or 1,cards=ids}','{act=run.act or 1,colorless=ids}')
  .replaceAll('state.cards','state.colorless');
 assert.equal(hash(stale),'5bb64f332e133f829be520fe65754f1277b655244cfe11cdec63db1139af5833');
 assert.notEqual(stale,live);assert.equal(prior(p,stale),stale);
 assert.throws(()=>requireSource(p,stale),/M3 event/);
 assert.equal(requireSource(p,live),null,'added module projects to the unchanged absent base');
});
