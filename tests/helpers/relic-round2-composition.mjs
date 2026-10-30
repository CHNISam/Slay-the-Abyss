// Historical evidence only: exact combined bytes recover either independently
// reviewed source. This never supplies source to current feature tests.
import assert from 'node:assert/strict';
import {cachePureSourceProjection,deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
import {preRelicRound3CompositionSource} from './relic-round3-composition.mjs';
import {preRelicArtCompositionSource} from './relic-art-composition.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./relic-round2-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'0e5b4ed9669e05d61bea4f3afde1f76cc0c321d42d1a524717eaed2c0de3a233','complete relic/round-two composition witness');
export const relicRound2Composition=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(relicRound2Composition.schemaVersion,1);
assert.equal(relicRound2Composition.currentCommit,'44a4e9b3e603e0619f99d7b77f9725ed0001a66c');
assert.deepEqual(Object.keys(relicRound2Composition.targets),['relic','round2']);
for(const target of Object.values(relicRound2Composition.targets))for(const [path,binding]of Object.entries(target.files)){
 assert.match(path,/^(?:config\/architecture\.json|scripts\/test-lua\.mjs|src\/lua\/abyss_(?:card_actions|combat|game_ui)\.lua)$/);
 for(const key of ['beforeSha256','afterSha256'])assert.match(binding[key],/^[a-f0-9]{64}$/);
 assert.notEqual(binding.beforeSha256,binding.afterSha256);
 let end=0,beforeEnd=0;
 for(const hunk of binding.hunks){
  assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=end&&Number.isSafeInteger(hunk.beforeAt)&&hunk.beforeAt>=beforeEnd);
  for(const line of [...hunk.before,...hunk.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
  end=hunk.at+hunk.after.length;beforeEnd=hunk.beforeAt+hunk.before.length;
 }
}
const cachedProjection=cachePureSourceProjection(relicRound2Composition.targets,projectSource);
export function preRelicRound2CompositionSource(path,source,target){return cachedProjection(path,source,target);}
function projectSource(path,source,target){
 source=preRelicRound3CompositionSource(path,source,'relic');
 source=preRelicArtCompositionSource(path,source,'relic');
 assert.ok(target==='relic'||target==='round2');
 const binding=relicRound2Composition.targets[target].files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 assert.equal(lines.length,binding.afterLines,'complete combined line inventory: '+path);
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact positioned combined hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(lines.length,binding.beforeLines);
 assert.equal(hash(previous),binding.beforeSha256,'complete independent source recovered: '+path);
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact positioned independent hunk: '+path);
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete forward composition recovered: '+path);
 return previous;
}
