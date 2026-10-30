// Pair pre-multi runtime with its actual Git03266 test source, never current UI acceptance.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/historical-battle-ui-cases.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'104987aa4c7a02260e99c9fcf4532b475fc25e49074aff8ffb8533fdf3dd0f6f','complete historical battle case proof');
export const historicalBattleUiCasesProof=deepFreezeSourceProof(JSON.parse(bytes));
const proof=historicalBattleUiCasesProof;
assert.equal(proof.baseCommit,'03266f668eb5ab6d7ed72d840fa55eafa90a819c');
assert.equal(proof.path,'tests/lua/support/battle_ui_cases.lua');
export function historicalBattleUiCases(source){
 assert.equal(typeof source,'string','historical battle case source required');
 const current=source.replaceAll('\r\n','\n');
 assert.equal(hash(current),proof.afterSha256,'unreviewed historical battle case source');
 assert.equal(blob(current),proof.afterGitBlob,'historical battle case current Git blob');
 const lines=current.split('\n');
 for(const h of [...proof.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.current.length),h.current,'historical battle case exact hunk');
  lines.splice(h.at,h.current.length,...h.prior);
 }
 const prior=lines.join('\n');
 assert.equal(hash(prior),proof.beforeSha256,'historical battle case complete parent');
 assert.equal(blob(prior),proof.beforeGitBlob,'historical battle case parent Git blob');
 return prior;
}
