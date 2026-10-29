import {preEventProductionSource} from './event-production-source-inverse.mjs';
// Exact outer composition only. Both accepted20a and original323 witnesses stay immutable.
import assert from 'node:assert/strict';
import {prePlayerDeathSource} from './player-death-transition-inverse.mjs';
import {preDeathSettlementGuardSource} from './death-settlement-guard-inverse.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/pr323-accepted-source-inverse.json',import.meta.url),'utf8');
assert.equal(hash(normalize(bytes)),'dea381bb8e2167ab13e01115f91f4b90dc42757b27627968d0549008a3ab8a03','complete accepted20a/original323 composition witness');
export const pr323AcceptedSourceInverse=JSON.parse(bytes);
const proof=pr323AcceptedSourceInverse;
assert.equal(proof.schemaVersion,1);
assert.equal(proof.acceptedBase,'20a74da73ff5379a748e6b9687b258e2c9a22bf8');
assert.equal(proof.originalPrHead,'39dab5e901616e7432df83d8c9dfc07305f01de6');
assert.ok(proof.files&&Object.keys(proof.files).length>0,'complete composition source inventory');
for(const [path,binding]of Object.entries(proof.files)){
 assert.ok(path&&!path.startsWith('/')&&!path.includes('\\')&&!path.split('/').some(part=>!part||part==='.'||part==='..'),'relative composition source path');
 assert.match(binding.afterSha256,/^[a-f0-9]{64}$/,'complete combined source identity: '+path);
 for(const target of ['accepted','original']){
  const source=binding[target+'Source'],expected=binding[target+'Sha256'];
  assert.ok(source===null||typeof source==='string','complete prior source: '+path);
  assert.equal(source===null?null:hash(normalize(source)),expected,'complete '+target+' prior source identity: '+path);
 }
}
export function requirePr323Source(path,source){
 source=preEventProductionSource(path,source);
 source=preDeathSettlementGuardSource(path,source);
 source=prePlayerDeathSource(path,source);
 const binding=proof.files[path];
 assert.ok(binding,'registered accepted20a/original323 composition source: '+path);
 assert.equal(typeof source,'string','combined composition source must exist: '+path);
 assert.equal(hash(normalize(source)),binding.afterSha256,'unreviewed integrated PR323 composition source: '+path);
 return binding;
}
function project(path,source,target){
 if(typeof source!=='string')return source;
 source=preEventProductionSource(path,source);
 source=preDeathSettlementGuardSource(path,source);
 source=prePlayerDeathSource(path,source);
 const normalized=normalize(source),binding=proof.files[path];
 // Unknown/partial sources remain visible to the original strict inner guards.
 if(!binding||hash(normalized)!==binding.afterSha256)return normalized;
 return binding[target+'Source']===null?null:normalize(binding[target+'Source']);
}
export function preAcceptedPr323Source(path,source){return project(path,source,'accepted');}
export function preOriginalPr323Source(path,source){return project(path,source,'original');}
export function readAcceptedPr323Source(path){return preAcceptedPr323Source(path,readFileSync(path,'utf8'));}
