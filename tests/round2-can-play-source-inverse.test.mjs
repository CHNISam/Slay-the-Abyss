import {preRound3CatalogSource} from './helpers/round3-catalog-source-inverse.mjs';
import {historicalTest as test,withHistoricalBaseline} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {preRelicRound2CompositionSource} from './helpers/relic-round2-composition.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {round2CanPlayProof as proof,preRound2CanPlaySource as prior} from './helpers/round2-can-play-source-inverse.mjs';
import {preNestedSnapshotOwnerSource,nestedSnapshotOwnerProof} from './helpers/nested-command-snapshot-owner-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const current=withHistoricalBaseline(()=>preRound3CatalogSource(proof.path,preRelicRound2CompositionSource(proof.path,readFileSync(proof.path,'utf8'),'round2')).replaceAll('\r\n','\n'));
test('exact canPlay outer delta recovers the full prior Combat identity',()=>{
 assert.equal(hash(current),proof.afterSha256);
 const original=prior(proof.path,current);
 assert.equal(hash(original),proof.beforeSha256);
 assert.equal(prior(proof.path,original),original);
 assert.equal(prior(proof.path,current.replaceAll('\n','\r\n')),original);
 assert.equal(hash(preNestedSnapshotOwnerSource(proof.path,current)),nestedSnapshotOwnerProof.files[proof.path].beforeSha256,
  'direct nested owner entry consumes this exact outer layer before its frozen witness');
});
test('canPlay inverse preserves unregistered, partial and future drift for strict inner guards',()=>{
 for(const source of [current+'\n-- future drift\n',current.slice(1),current.replace(proof.after,proof.before),
  current.replace('if card.costMode or card.condition then','if false then')]){
  assert.notEqual(source,current);
  assert.equal(prior(proof.path,source),source);
 }
 assert.equal(prior('src/lua/abyss_run.lua',current),current);
 assert.equal(prior(proof.path,null),null);
});
