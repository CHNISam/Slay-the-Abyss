import assert from'node:assert/strict';
import{readFileSync,mkdtempSync,writeFileSync,rmSync}from'node:fs';
import{join}from'node:path';import{tmpdir}from'node:os';
import{toLua}from'../../scripts/build-lua-data.mjs';import{runLua}from'../../scripts/test-lua.mjs';
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-prismatic-rewards.json'));
export function prismaticCase({omitLong=false,omitRetryLong=false}={}){
 const dir=mkdtempSync(join(tmpdir(),'prismatic-'));try{
  let prelude='';
  if(omitLong||omitRetryLong){
   const original=readFileSync('src/lua/abyss_card_pool.lua','utf8');
   const target='            if prismatic then R.randomLongHex(rng)end';
   assert.equal(original.split(target).length,2,'one exact Prismatic shuffle-long consumption');
   const path=join(dir,'abyss_card_pool.lua');writeFileSync(path,original.replace(target,omitRetryLong?'            if prismatic and not used[id] then R.randomLongHex(rng)end':'            -- MUTANT: omitted Prismatic shuffle-long consumption'));
   prelude=`package.loaded.abyss_card_pool=dofile(${JSON.stringify(path)});`;
  }
  const path=join(dir,'case.lua');writeFileSync(path,`${prelude}dofile('tests/lua/support/prismatic_rewards.lua')(${toLua(vectors.case)},${toLua(vectors.pools)})`);
  const r=runLua(path);
  if(omitLong||omitRetryLong){assert.notEqual(r.status,0,r.stdout+r.stderr);assert.match(r.stderr,omitRetryLong?/normal_act2 exact long\/identity\/retry draw count/:/boss exact long\/identity\/retry draw count/);console.log('PRISMATIC_OMIT_LONG_REJECTED '+r.stderr.split('\n')[0]);}
  else{assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/PRISMATIC_REWARDS_PASS 275 wrappers/);}
 }finally{rmSync(dir,{recursive:true,force:true});}
}
