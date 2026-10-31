import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-chaos-shared-chain.json'));
function run(sample,mutation){
 const directory=mkdtempSync(join(tmpdir(),'chaos-shared-chain-'));
 try{
  let prelude='';
  if(mutation){
   const source=readFileSync(`src/lua/${mutation.module}.lua`,'utf8');
   assert.equal(source.split(mutation.before).length,2,'mutant deletes exactly one registered consumption site');
   const path=join(directory,'mutant.lua');writeFileSync(path,source.replace(mutation.before,mutation.after));
   prelude=`package.loaded[${toLua(mutation.module)}]=dofile(${toLua(path)});`;
  }
  const path=join(directory,'case.lua');writeFileSync(path,`${prelude}dofile('tests/lua/support/chaos_shared_chain.lua')(${toLua(sample)},${toLua(fixture.fullPool)})`);
  return runLua(path);
 }finally{rmSync(directory,{recursive:true,force:true});}
}
export function registerSeed(seed){
 const sample=fixture.cases.find(row=>row.seed===seed);assert.ok(sample,'registered Chaos source seed');
 test(`Chaos target preplanning and real Hand/Spoon/Branch share exact independent stream seed ${seed}`,()=>{
  const result=run(sample);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/CHAOS_SHARED_CHAIN_PASS/);
 });
}
const mutations={
 preplan:{name:'one final target preplan',module:'abyss_inventory',before:'local chosenTarget=#pool>0 and pool[Combat.cardRandom(state,#pool)] or nil',after:'local chosenTarget=_==value and pool[1] or (#pool>0 and pool[Combat.cardRandom(state,#pool)] or nil)'},
 spoon:{name:'one played-card Spoon boolean',module:'abyss_shop_relics',before:'return not R.randomBoolean(state.cardRandomRng)',after:'return false -- mutation omits exactly one Spoon boolean'},
};
export function registerMutation(name){
 const mutation=mutations[name];assert.ok(mutation,'registered exact Chaos mutation');
 test(`Chaos independent chain rejects removal of ${mutation.name}`,()=>{
  const result=run(fixture.cases[0],mutation);assert.notEqual(result.status,0,result.stdout+result.stderr);
  assert.match(result.stderr,/every Chaos shared stream draw/);
 });
}
