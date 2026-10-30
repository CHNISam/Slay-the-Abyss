import {prePostBetaRuntimeSource,postBetaRuntimeHistoricalPaths} from './post-beta-runtime-source.mjs';
import {preDeckDeliverySource,deckDeliveryPaths} from './deck-delivery-source-composition.mjs';
import {gunzipSync} from 'node:zlib';
// Exact Git composition, historical evidence only; current runtime never imports this.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync,realpathSync,writeFileSync,rmSync} from 'node:fs';
import {join,relative,isAbsolute,win32,posix} from 'node:path';
import {cachePureSourceProjection,deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/delivery-source-composition.json.gz',import.meta.url));
assert.equal(hash(bytes),'d7bf28b224aaec821ac215f81adcef436fff51b009c21ef8b75d50bd16c2fa4b');
export const deliverySourceProof=deepFreezeSourceProof(JSON.parse(gunzipSync(bytes)));
const proof=deliverySourceProof;
assert.equal(proof.schemaVersion,1);
assert.deepEqual(Object.keys(proof.targets),['developEvents','develop','legacyM3','legacyMulti','legacyUiSupport','pre379']);
for(const [name,target]of Object.entries(proof.targets)){
 assert.match(target.beforeCommit,/^[a-f0-9]{40}$/);assert.match(target.afterCommit,/^[a-f0-9]{40}$/);
 assert.deepEqual(Object.keys(target.files),Object.keys(target.files).sort());
 for(const [path,b]of Object.entries(target.files)){
  assert.ok(/^(?:src\/lua\/[^/]+\.lua|(?:scripts|config|data|tools)\/[A-Za-z0-9_.\/-]+|tests\/lua\/support\/(?:game_ui_fixture|battle_gesture_fixture)\.lua)$/.test(path)&&!path.split('/').includes('..'),'relative exact source path: '+path);
  assert.match(b.afterSha256,/^[a-f0-9]{64}$/);assert.match(b.afterGitBlob,/^[a-f0-9]{40}$/);assert.notEqual(b.beforeSha256,b.afterSha256);
  if(b.beforeSha256===null){assert.equal(b.beforeGitBlob,null);assert.deepEqual(b.hunks,[]);}
  else{assert.match(b.beforeSha256,/^[a-f0-9]{64}$/);assert.match(b.beforeGitBlob,/^[a-f0-9]{40}$/);}
  let end=0,oldEnd=0;for(const h of b.hunks){
   assert.ok(Number.isSafeInteger(h.at)&&h.at>=end&&Number.isSafeInteger(h.beforeAt)&&h.beforeAt>=oldEnd);
   for(const line of [...h.before,...h.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
   end=h.at+h.after.length;oldEnd=h.beforeAt+h.before.length;
  }
 }
}
const lengthBytes=normalize(readFileSync(new URL('../fixtures/delivery-source-lengths.json',import.meta.url),'utf8'));
assert.equal(hash(lengthBytes),'e569608426e527aaba4416f0f294744c626fd3e43650dfebfb1370caa7d7d67f','complete Git-derived source length witness');
export const deliverySourceLengths=deepFreezeSourceProof(JSON.parse(lengthBytes));
assert.equal(deliverySourceLengths.schemaVersion,1);
assert.equal(deliverySourceLengths.proofSha256,hash(bytes));
assert.equal(deliverySourceLengths.normalization,'CRLF-to-LF');
assert.equal(deliverySourceLengths.measure,'UTF-16-code-units');
assert.deepEqual(Object.keys(deliverySourceLengths.targets),Object.keys(proof.targets));
for(const [target,{files}]of Object.entries(proof.targets)){
 assert.deepEqual(Object.keys(deliverySourceLengths.targets[target]),Object.keys(files));
 for(const [path,b]of Object.entries(files)){
  const length=deliverySourceLengths.targets[target][path];
  assert.equal(length.afterSha256,b.afterSha256);assert.equal(length.afterGitBlob,b.afterGitBlob);
  assert.ok(Number.isSafeInteger(length.utf16Length)&&length.utf16Length>=0);
 }
}
const readLive=p=>readFileSync(p,'utf8');
const inverse=cachePureSourceProjection(proof.targets,(path,source,target)=>{
 assert.ok(proof.targets[target],'registered integrated monster target');
 const b=proof.targets[target].files[path];if(!b||typeof source!=='string')return undefined;
 const s=normalize(source);
 // Length is only an impossible-match rejection, never permission to project.
 // Equal lengths still execute every existing SHA/Git-blob/owner validation.
 if(s.length!==deliverySourceLengths.targets[target][path].utf16Length||hash(s)!==b.afterSha256)return undefined;
 assert.equal(blob(s),b.afterGitBlob,'complete integrated source Git blob: '+path);
 if(b.beforeSha256===null)return null;
 const lines=s.split('\n');assert.equal(lines.length,b.afterLines);
 for(const h of [...b.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact integrated inverse hunk: '+path);
  lines.splice(h.at,h.after.length,...h.before);
 }
 const prior=lines.join('\n');assert.equal(lines.length,b.beforeLines);assert.equal(hash(prior),b.beforeSha256);assert.equal(blob(prior),b.beforeGitBlob);
 const forward=[...lines];for(const h of [...b.hunks].reverse()){
  assert.deepEqual(forward.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);forward.splice(h.beforeAt,h.before.length,...h.after);
 }
 assert.equal(forward.join('\n'),s,'exact integrated forward source: '+path);return prior;
});
export function tryDeliverySource(path,source,target,{readSource=readLive}={}){
 source=prePostBetaRuntimeSource(path,source,{readSource});
 source=preDeckDeliverySource(path,source,'delivery',{readSource});
 const prior=inverse(path,source,target);if(prior===undefined)return undefined;
 // Every call re-reads linked owners. No cache may cover this validation.
 for(const [p,b]of Object.entries(proof.targets[target].files).filter(([,b])=>b.beforeSha256===null)){
  const label='delivery linked source';
  let live;try{live=prePostBetaRuntimeSource(p,readSource(p),{readSource});}catch{assert.fail(label+' missing: '+p);}
  if(target==='develop'||target==='pre379'){const projected=inverse(p,live,'developEvents');if(projected!==undefined)live=projected;}
  if(target==='pre379'){const projected=inverse(p,live,'develop');if(projected!==undefined)live=projected;}
  assert.equal(typeof live,'string',label+' must exist: '+p);
  assert.equal(hash(normalize(live)),b.afterSha256,label+' identity: '+p);
 }
 return prior;
}
export function preDeliveryTargetSource(path,source,target,options){
 source=prePostBetaRuntimeSource(path,source,options);
 source=preDeckDeliverySource(path,source,'delivery',options);
 const prior=tryDeliverySource(path,source,target,options);return prior===undefined?source:prior;
}
export function deliveryHistoricalPaths(target){return Object.freeze([...new Set([...postBetaRuntimeHistoricalPaths,...deckDeliveryPaths,...((target==='develop'||target==='pre379')?Object.keys(proof.targets.developEvents.files):[]),...(target==='pre379'?Object.keys(proof.targets.develop.files):[]),...Object.keys(proof.targets[target].files)])].sort());}
export function verifiedDeliverySources(target,{sourceRoot=process.cwd(),readSource=p=>readFileSync(join(sourceRoot,p),'utf8')}={}){
 assert.ok(target==='develop'||target==='pre379'||target==='legacyMulti');const outputs=[];
 for(const path of deliveryHistoricalPaths(target)){
  const raw=preDeckDeliverySource(path,prePostBetaRuntimeSource(path,readSource(path),{readSource}),'delivery',{readSource}),outer=(target==='develop'||target==='pre379')?proof.targets.developEvents.files[path]:undefined;
  assert.equal(typeof raw,'string','unreviewed current integrated monster source missing: '+path);
  if(outer)assert.equal(hash(normalize(raw)),outer.afterSha256,'unreviewed current integrated monster source: '+path);
  let source=(target==='develop'||target==='pre379')?preDeliveryTargetSource(path,raw,'developEvents',{readSource}):raw;
  if(target==='pre379'){const middle=proof.targets.develop.files[path];if(middle){assert.equal(typeof source,'string','unreviewed current delivery middle source missing: '+path);assert.equal(hash(normalize(source)),middle.afterSha256,'unreviewed current delivery middle source: '+path);}source=preDeliveryTargetSource(path,source,'develop',{readSource});}
  const inner=proof.targets[target].files[path];
  if(inner){assert.equal(typeof source,'string','integrated prior existence: '+path);assert.equal(hash(normalize(source)),inner.afterSha256,'unreviewed current integrated monster source: '+path);source=preDeliveryTargetSource(path,source,target,{readSource});}
  outputs.push([path,source]);
 }
 return outputs;
}
export function requireIsolatedDeliveryPath(destination,actual,style='native'){
 assert.ok(['native','win32','posix'].includes(style),'known isolated path syntax');
 const api=style==='native'?{relative,isAbsolute}:style==='win32'?win32:posix;
 const within=api.relative(destination,actual);
 assert.ok(within&&!within.startsWith('..')&&!api.isAbsolute(within),'integrated destination stays in isolated copy');
}
export function materializeBeforeDelivery(directory,{sourceRoot=process.cwd()}={}){
 const destination=realpathSync(directory),live=realpathSync(sourceRoot);assert.notEqual(destination,live,'integrated replay requires separate historical destination');
 const outputs=verifiedDeliverySources('pre379',{sourceRoot});
 for(const [path,source]of outputs){
  const target=join(directory,path);if(!existsSync(target))continue;
  const actual=realpathSync(target);
  requireIsolatedDeliveryPath(destination,actual);
  assert.notEqual(actual,realpathSync(join(sourceRoot,path)),'integrated destination cannot alias live source');
  const readSource=p=>readFileSync(join(sourceRoot,p),'utf8');
  const digest=hash(normalize(preDeckDeliverySource(path,prePostBetaRuntimeSource(path,readFileSync(target,'utf8'),{readSource}),'delivery',{readSource}))),raw=hash(normalize(preDeckDeliverySource(path,prePostBetaRuntimeSource(path,readSource(path),{readSource}),'delivery',{readSource})));
  assert.ok(digest===raw||(source!==null&&digest===hash(normalize(source))),'unreviewed integrated destination: '+path);
 }
 for(const [path,source]of outputs){const target=join(directory,path);if(!existsSync(target))continue;if(source===null)rmSync(target);else writeFileSync(target,source);}
}

export function preDeliverySource(path,source,options){return preDeliveryTargetSource(path,preDeliveryTargetSource(path,source,'developEvents',options),'develop',options);}
export const preLegacyM3Source=(path,source,options)=>preDeliveryTargetSource(path,source,'legacyM3',options);
export const preLegacyMultiSource=(path,source,options)=>preDeliveryTargetSource(path,source,'legacyMulti',options);
export const preLegacyUiSupportSource=(path,source,options)=>preDeliveryTargetSource(path,source,'legacyUiSupport',options);

export const preAcceptedDevelopSource=(path,source,options)=>preDeliveryTargetSource(path,preDeliverySource(path,source,options),'pre379',options);
