import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {historicalBattleUiCasesProof as proof, historicalBattleUiCases} from './helpers/historical-battle-ui-cases.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
test('historical replay recovers complete Git03266 battle cases without changing live assertions',()=>{
 const live=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n');
 const prior=historicalBattleUiCases(live);
 assert.equal(hash(prior),proof.beforeSha256);assert.equal(blob(prior),proof.beforeGitBlob);
 assert.equal(historicalBattleUiCases(live.replaceAll('\n','\r\n')),prior);
 const lines=prior.split('\n');
 for(const h of [...proof.hunks].reverse()){
  assert.deepEqual(lines.slice(h.beforeAt,h.beforeAt+h.prior.length),h.prior);
  lines.splice(h.beforeAt,h.prior.length,...h.current);
 }
 assert.equal(lines.join('\n'),live);
 assert.equal(hash(readFileSync(proof.path,'utf8').replaceAll('\r\n','\n')),proof.afterSha256);
});
test('historical case admission rejects changed assertions, partial inverses and missing source',()=>{
 const live=readFileSync(proof.path,'utf8');
 const partial=live.replace(proof.hunks[0].current.join('\n'),proof.hunks[0].prior.join('\n'));
 for(const bad of [live+'\n',live.replace('assert(stage.children.notice.text == "")','assert(true)'),partial,undefined,null]){
  assert.throws(()=>historicalBattleUiCases(bad),/historical battle case/);
 }
});
