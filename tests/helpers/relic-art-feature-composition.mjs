import {preM3EventDeliverySource} from './m3-event-delivery-source-inverse.mjs';
// Single-path historical composition only; runtime loads actual production.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {cachePureSourceProjection,deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./relic-art-feature-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'857ac2e1af7f46acba4fadc750762f1093935cde8849a7586bf96309ca70eb1a','complete relic/art-feature Git composition witness');
export const relicArtFeatureComposition=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(relicArtFeatureComposition.schemaVersion,1);
assert.equal(relicArtFeatureComposition.currentCommit,'e20a9915de80a1af62271e881a42499129939e31');
assert.deepEqual(Object.fromEntries(Object.entries(relicArtFeatureComposition.targets).map(([key,value])=>[key,value.commit])),{
 relic:'7cafb51a03200c5b173f569a5a409cf29e30f773',artFeature:'86fb0b137496bb5ef3cdeb4d37ab69eec3f38a4b',
});
for(const target of Object.values(relicArtFeatureComposition.targets)){
 assert.deepEqual(Object.keys(target.files),['scripts/verify-launch-content.mjs']);
 for(const binding of Object.values(target.files)){
  for(const key of ['beforeSha256','afterSha256'])assert.match(binding[key],/^[a-f0-9]{64}$/);
  assert.match(binding.beforeGitBlobSha1,/^[a-f0-9]{40}$/);
  assert.notEqual(binding.beforeSha256,binding.afterSha256);
  let end=0,beforeEnd=0;
  for(const hunk of binding.hunks){
   assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=end&&Number.isSafeInteger(hunk.beforeAt)&&hunk.beforeAt>=beforeEnd);
   for(const line of [...hunk.before,...hunk.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
   end=hunk.at+hunk.after.length;beforeEnd=hunk.beforeAt+hunk.before.length;
  }
 }
}
const cachedProjection=cachePureSourceProjection(relicArtFeatureComposition.targets,projectSource);
export function preRelicArtFeatureCompositionSource(path,source,target){return cachedProjection(path,preM3EventDeliverySource(path,source),target);}
function projectSource(path,source,target){
 assert.ok(target==='relic'||target==='artFeature');
 const binding=relicArtFeatureComposition.targets[target].files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 assert.equal(lines.length,binding.afterLines,'complete combined art-feature line inventory');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact positioned art-feature composition hunk');
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(lines.length,binding.beforeLines);
 assert.equal(hash(previous),binding.beforeSha256,'complete independent art-feature/relic identity');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),binding.beforeGitBlobSha1,'locked Git target blob');
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact positioned target hunk');
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete forward art-feature/relic composition');
 return previous;
}
