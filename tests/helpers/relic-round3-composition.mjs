// Exact historical evidence only; current feature execution uses production.
import assert from 'node:assert/strict';
import {cachePureSourceProjection,deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./relic-round3-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'2e3f3f551f1c99b39b6c8028ce2abea49ed33a1e8b6c11097898e2145ff02736','complete relic/round-three Git composition witness');
export const relicRound3Composition=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(relicRound3Composition.schemaVersion,1);
assert.equal(relicRound3Composition.currentCommit,'9ed3bb24cdf298d9ce8c9708f9658a1d764af12b');
assert.deepEqual(Object.fromEntries(Object.entries(relicRound3Composition.targets).map(([key,value])=>[key,value.commit])),{
 relic:'7b9ba4ab9af438a1e875f1883b27469ee164eb31',round3:'157cd1a2c9d3e1cb5c40e374a49840dda7e103f1',
});
for(const target of Object.values(relicRound3Composition.targets)){
 assert.deepEqual(Object.keys(target.files),['config/architecture.json','src/lua/abyss_card_actions.lua','src/lua/abyss_combat.lua']);
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
const cachedProjection=cachePureSourceProjection(relicRound3Composition.targets,projectSource);
export function preRelicRound3CompositionSource(path,source,target){return cachedProjection(path,source,target);}
function projectSource(path,source,target){
 assert.ok(target==='relic'||target==='round3');
 const binding=relicRound3Composition.targets[target].files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 assert.equal(lines.length,binding.afterLines,'complete combined round-three line inventory: '+path);
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact positioned combined round-three hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(lines.length,binding.beforeLines);
 assert.equal(hash(previous),binding.beforeSha256,'complete independent round-three/relic identity: '+path);
 const blobHeader='blob '+Buffer.byteLength(previous)+'\0';
 assert.equal(createHash('sha1').update(blobHeader).update(previous).digest('hex'),binding.beforeGitBlobSha1,'actual locked Git target blob: '+path);
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact positioned Git target hunk: '+path);
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete forward round-three/relic composition: '+path);
 return previous;
}
