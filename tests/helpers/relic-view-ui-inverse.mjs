import {preBattleLifeSource} from './battle-life-source-inverse.mjs';
import {projectOpenPrSource} from './open-pr-source-composition.mjs';
// Exact outer projection for the TASK-4.7 relic view UI delta only. All
// historical composition witnesses stay frozen; partial bytes reach strict guards.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/relic-view-ui-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'749098fab752f80110fa7b277e8f83adb6e4e03a84bbcf680fee65bc94a9c36c','complete exact relic view UI layer identity');
export const relicViewUiProof=JSON.parse(bytes);
assert.equal(relicViewUiProof.base,'806ea465bb4cb5a677a314c880dbd46710476e82');
export function preRelicViewUiSource(path,source){
 source=preBattleLifeSource(path,source);
 if(relicViewUiProof.files[path])source=projectOpenPrSource(path,source,'relic');
 if(typeof source!=='string')return source;
 source=normalize(source);
 const binding=relicViewUiProof.files[path];
 if(!binding||hash(source)!==binding.afterSha256)return source;
 const lines=source.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact relic view UI hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const accepted=lines.join('\n');
 assert.equal(hash(accepted),binding.beforeSha256,'complete accepted develop source recovered: '+path);
 return accepted;
}
