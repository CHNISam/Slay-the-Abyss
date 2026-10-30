import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {smallSlimesReferenceFixture as proof,preSmallSlimesReferenceFixtureSource as before} from './helpers/small-slimes-reference-fixture-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
test('small slime hook-owner reference repair restores the complete frozen fixture in both directions',()=>{
 const current=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'),previous=before(proof.path,current);
 assert.equal(hash(current),proof.afterSha256);assert.equal(hash(previous),proof.beforeSha256);
 assert.equal(before(proof.path,current.replaceAll('\n','\r\n')),previous);
 assert.equal(before(proof.path,previous),previous);
 const hunk=proof.hunks[0];assert.equal(previous.split(hunk.before).length,2);
 assert.equal(previous.replace(hunk.before,hunk.after),current);
});
test('partial, duplicated, moved, and assertion-changing edits remain exposed to the frozen whole-body gate',()=>{
 const current=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'),hunk=proof.hunks[0];
 for(const mutant of [current+'\n',current.replace('        reference.shopRelicCombat={pellets={}}\n',''),
  current.replace(hunk.after,hunk.after+hunk.after),current.replace(hunk.after,'')+hunk.after,
  current.replace('eq(seen,16)','eq(seen,15)'),current.replace('same(run.combat,expectedBattle)','same(run.combat,run.combat)'),
  current.replace('topCanDraw=true','topCanDraw=false')]){
  assert.notEqual(mutant,current);
  assert.equal(before(proof.path,mutant),mutant);assert.notEqual(hash(mutant),proof.beforeSha256);
 }
});
