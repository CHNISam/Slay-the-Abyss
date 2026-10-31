import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fixture,execute} from './helpers/merchant-chain.mjs';
test('merchant source oracle regenerates and explicitly covers all initial and replacement consumers',()=>{
 execFileSync('python',['tools/oracles/sts1_merchant_chain.py','--check']);
 assert.deepEqual(fixture.cases.map(c=>c.caseId),['0/ordinary','1/courier','-1/both','42/membership-purchase']);
 for(const c of fixture.cases){
  assert.equal(c.steps[0].traceCounts.merchant,16);
  if(c.courier){
   assert.deepEqual(c.steps.map(s=>s.label),['initial','colored','colorless','potion','relic']);
   assert.deepEqual(c.steps.map(s=>s.traceCounts.merchant),[16,17,19,20,22]);
  }
 }
});
test('merchant exact source chain rejects omission of the initial sale-slot draw',()=>{
 const dir=mkdtempSync(join(tmpdir(),'merchant-sale-mutant-'));
 try{
  const source=readFileSync('src/lua/abyss_shop.lua','utf8'),target='local sale=R.randomInt(rng.merchant,4)+1';
  assert.equal(source.split(target).length,2);
  const path=join(dir,'shop.lua');writeFileSync(path,source.replace(target,'local sale=1 -- omit one source draw'));
  const r=execute('0/ordinary',`package.loaded.abyss_shop=dofile(${JSON.stringify(path)})`);
  assert.notEqual(r.status,0);assert.match(r.stderr,/initial merchant exact draw count/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
