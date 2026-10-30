import {preLegacyM3Source} from './delivery-source-composition.mjs';
// Exact test-only c3cb94c8 -> 1fcd replay. Current feature tests load live code.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync,realpathSync,writeFileSync,rmSync} from 'node:fs';
import {join,resolve,relative,isAbsolute} from 'node:path';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/m3-event-delivery-source-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'69cd0dbe5e40f1a9d4a342e89823f7411b77b9bdca6ce15f291bb0c49db0778e','complete M3 event delivery inverse');
export const m3EventDeliveryProof=deepFreezeSourceProof(JSON.parse(bytes));
const proof=m3EventDeliveryProof;
assert.equal(proof.schemaVersion,1);
assert.equal(proof.baseCommit,'1fcd321ca9d6f79b4e5bbdfede48069119f5ed52');
assert.equal(proof.sourceCommit,'c3cb94c83715c38446a82c1386f41fdd02a5d353');
assert.equal(Object.keys(proof.files).length,62);
assert.deepEqual(Object.keys(proof.files),Object.keys(proof.files).sort());
for(const [path,b]of Object.entries(proof.files)){
 assert.match(path,/^(?:tools\/render_traveler_cards\.py|src\/lua\/[^/]+\.lua|scripts\/[^/]+\.(?:mjs|lua)|config\/[^/]+\.json|data\/(?:[^/]+\.json|(?:presentation|release)\/[^/]+\.json))$/);
 assert.notEqual(b.beforeSha256,b.afterSha256);
 assert.match(b.afterSha256,/^[a-f0-9]{64}$/);assert.match(b.afterGitBlob,/^[a-f0-9]{40}$/);
 if(b.beforeSha256===null){assert.equal(b.beforeGitBlob,null);assert.deepEqual(b.hunks,[]);}
 else{assert.match(b.beforeSha256,/^[a-f0-9]{64}$/);assert.match(b.beforeGitBlob,/^[a-f0-9]{40}$/);}
 let end=0,beforeEnd=0;
 for(const h of b.hunks){
  assert.ok(Number.isSafeInteger(h.at)&&h.at>=end&&Number.isSafeInteger(h.beforeAt)&&h.beforeAt>=beforeEnd);
  for(const line of [...h.before,...h.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
  end=h.at+h.after.length;beforeEnd=h.beforeAt+h.before.length;
 }
}
export const m3EventAddedPaths=Object.freeze(Object.keys(proof.files).filter(p=>proof.files[p].beforeSha256===null));
const defaultRead=p=>readFileSync(p,'utf8');
function requireBytes(path,source){
 source=preLegacyM3Source(path,source);
 const b=proof.files[path];assert.ok(b,'registered M3 event source: '+path);
 assert.equal(typeof source,'string','missing M3 event source: '+path);
 const s=normalize(source);assert.equal(hash(s),b.afterSha256,'unreviewed M3 event source: '+path);
 assert.equal(blob(s),b.afterGitBlob,'M3 event Git blob: '+path);return s;
}
function requireLinked(readSource){
 for(const p of m3EventAddedPaths){let s;try{s=readSource(p);}catch{assert.fail('missing M3 event linked source: '+p);}requireBytes(p,s);}
}
export function preM3EventDeliverySource(path,source,{readSource=defaultRead}={}){
 source=preLegacyM3Source(path,source,{readSource});
 const b=proof.files[path];if(!b||typeof source!=='string')return source;
 const normalized=normalize(source);if(hash(normalized)!==b.afterSha256)return source;
 // Never memoize this live read, including when an outer pure projection caches.
 requireLinked(readSource);requireBytes(path,source);
 if(b.beforeSha256===null)return null;
 const lines=normalized.split('\n');assert.equal(lines.length,b.afterLines);
 for(const h of [...b.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact M3 inverse position: '+path);
  lines.splice(h.at,h.after.length,...h.before);
 }
 const previous=lines.join('\n');assert.equal(lines.length,b.beforeLines);
 assert.equal(hash(previous),b.beforeSha256,'complete M3 prior identity: '+path);
 assert.equal(blob(previous),b.beforeGitBlob,'complete M3 prior Git blob: '+path);
 const forward=[...lines];for(const h of [...b.hunks].reverse()){
  assert.deepEqual(forward.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);
  forward.splice(h.beforeAt,h.before.length,...h.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete M3 forward identity: '+path);return previous;
}
export function requireM3EventDeliverySource(path,source,options){requireBytes(path,source);return preM3EventDeliverySource(path,source,options);}
export function materializeBeforeM3EventDelivery(directory,{sourceRoot=process.cwd()}={}){
 const destination=realpathSync(directory),live=realpathSync(sourceRoot);
 assert.notEqual(destination,live,'M3 replay requires separate historical destination');
 const rawRead=p=>readFileSync(join(sourceRoot,p),'utf8');
 const readSource=p=>preLegacyM3Source(p,rawRead(p),{readSource:rawRead});
 // Validate all live inputs and all targets before any mutation.
 for(const p of Object.keys(proof.files))requireBytes(p,readSource(p));
 const outputs=[];
 for(const [p,b]of Object.entries(proof.files)){
  const target=join(directory,p);if(!existsSync(target))continue;
  const actual=realpathSync(target),within=relative(destination,actual);
  assert.ok(within&&!within.startsWith('..')&&!isAbsolute(within),'M3 destination stays inside copy');
  assert.notEqual(actual,realpathSync(join(sourceRoot,p)),'M3 destination cannot alias live source');
  const source=preLegacyM3Source(p,readFileSync(target,'utf8'),{readSource:rawRead}),digest=hash(normalize(source));
  assert.ok(digest===b.afterSha256||digest===b.beforeSha256,'unreviewed M3 destination: '+p);
  if(digest===b.afterSha256)outputs.push([target,preM3EventDeliverySource(p,source,{readSource})]);
 }
 for(const [target,source]of outputs){if(source===null)rmSync(target);else writeFileSync(target,source);}
}
