import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gremlinGangOwnerFixture as proof,preGremlinGangOwnerFixtureSource as before} from './helpers/gremlin-gang-owner-fixture-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
test('Gremlin independent hook-owner expectation restores the entire frozen helper in both directions',()=>{
 const current=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'),previous=before(proof.path,current);
 assert.equal(hash(current),proof.afterSha256);assert.equal(hash(previous),proof.beforeSha256);
 assert.equal(before(proof.path,current.replaceAll('\n','\r\n')),previous);
 assert.equal(before(proof.path,previous),previous);
 const hunk=proof.hunks[0];assert.equal(previous.split(hunk.before).length,2);
 assert.equal(previous.replace(hunk.before,hunk.after),current);
});
test('partial, duplicate, moved or unrelated Gremlin state assertions stay exposed to the original body gate',()=>{
 const current=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'),hunk=proof.hunks[0];
 for(const mutant of [current+'\n',current.replace(' reference.shopRelicCombat={pellets={}}\n',''),
  current.replace(hunk.after,hunk.after+hunk.after),current.replace(hunk.after,'')+hunk.after,
  current.replace('topCanDraw=true','topCanDraw=false'),current.replace('same(run.combat,reference)','same(run.combat,run.combat)'),
  current.replace("eq(count,expected,'registered original groups')","eq(count,18,'registered original groups')")]){
  assert.notEqual(mutant,current);assert.equal(before(proof.path,mutant),mutant);
  assert.notEqual(hash(mutant),proof.beforeSha256);
 }
});
