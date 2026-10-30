import {preM3EventDeliverySource} from './m3-event-delivery-source-inverse.mjs';
// Historical source evidence only. Current feature tests use actual production.
import assert from 'node:assert/strict';
import {preRelicArtFeatureCompositionSource} from './relic-art-feature-composition.mjs';
import {cachePureSourceProjection,deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./relic-art-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'68a179c3f7e63fc77b5944618e089c83d6f72a762775ca1a270a12c61597a77e','complete relic/art composition witness');
export const relicArtComposition=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(relicArtComposition.schemaVersion,1);
assert.equal(relicArtComposition.currentCommit,'ae32156a9428d21fe3822d43482bc2993b273ada');
assert.deepEqual(Object.keys(relicArtComposition.targets),['relic','art']);
for(const target of Object.values(relicArtComposition.targets))for(const [path,binding]of Object.entries(target.files)){
 assert.match(path,/^(?:config\/architecture\.json|scripts\/verify-launch-content\.mjs|src\/lua\/abyss_game_ui\.lua)$/);
 for(const key of ['beforeSha256','afterSha256'])assert.match(binding[key],/^[a-f0-9]{64}$/);
 assert.notEqual(binding.beforeSha256,binding.afterSha256);
 let end=0,beforeEnd=0;
 for(const hunk of binding.hunks){
  assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=end&&Number.isSafeInteger(hunk.beforeAt)&&hunk.beforeAt>=beforeEnd);
  for(const line of [...hunk.before,...hunk.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
  end=hunk.at+hunk.after.length;beforeEnd=hunk.beforeAt+hunk.before.length;
 }
}
const cachedProjection=cachePureSourceProjection(relicArtComposition.targets,projectSource);
export function preRelicArtCompositionSource(path,source,target){return cachedProjection(path,preM3EventDeliverySource(path,source),target);}
function projectSource(path,source,target){
 source=preRelicArtFeatureCompositionSource(path,source,'relic');
 assert.ok(target==='relic'||target==='art');
 const binding=relicArtComposition.targets[target].files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 assert.equal(lines.length,binding.afterLines,'complete combined art line inventory: '+path);
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact positioned combined art hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(lines.length,binding.beforeLines);
 assert.equal(hash(previous),binding.beforeSha256,'complete independent art/relic source recovered: '+path);
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact positioned independent art/relic hunk: '+path);
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete forward art/relic composition recovered: '+path);
 return previous;
}
