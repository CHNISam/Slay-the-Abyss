import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync}from'node:fs';
import {join}from'node:path';import{tmpdir}from'node:os';
import{toLua}from'../../scripts/build-lua-data.mjs';import{runLua}from'../../scripts/test-lua.mjs';
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-card-consumers.json'));
export function cardConsumerCase({omitRetry=false}={}){
 const dir=mkdtempSync(join(tmpdir(),'card-consumers-'));try{
  let prelude='';
  if(omitRetry){
   const original=readFileSync('src/lua/abyss_card_pool.lua','utf8');
   const target='            id=pool[R.randomInt(rng,#pool-1)+1]';assert.equal(original.split(target).length,2,'one exact identity site');
   // Remove exactly the first retry draw, without touching rarity or any other
   // RNG operation. Pool[1] is an explicit arbitrary candidate for the mutant.
   const changed=original.replace('local M={}','local M={}\nlocal omittedIdentity=false').replace(target,
    '            if used[id] and not omittedIdentity then omittedIdentity=true;id=pool[1]\n            else id=pool[R.randomInt(rng,#pool-1)+1]end');
   const module=join(dir,'abyss_card_pool.lua');writeFileSync(module,changed);
   prelude=`package.loaded.abyss_card_pool=dofile(${JSON.stringify(module)});`;
  }
  const path=join(dir,'case.lua');writeFileSync(path,`${prelude}dofile('tests/lua/support/card_consumers.lua')(${toLua(vectors.case)},${toLua(vectors.pools)})`);
  const r=runLua(path);
  if(omitRetry){assert.notEqual(r.status,0,r.stdout+r.stderr);assert.match(r.stderr,/orrery identities|orrery owner|complete rarity\/identity/);console.log('CARD_CONSUMER_MUTANT_REJECTED '+r.stderr.split('\n')[0]);}
  else{assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/CARD_CONSUMERS_PASS 93 wrappers/);}
 }finally{rmSync(dir,{recursive:true,force:true});}
}
