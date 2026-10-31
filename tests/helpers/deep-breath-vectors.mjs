import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-deep-breath.json'));
export function runSeed(seed,mutation){
 const directory=mkdtempSync(join(tmpdir(),'deep-breath-source-'));
 try{
  let prelude='';
  if(mutation){
   const source=readFileSync('src/lua/abyss_colorless_cards.lua','utf8');assert.equal(source.split(mutation.before).length,2,'one exact source mutation');
   prelude=`package.preload['abyss_colorless_cards']=function()return assert(load(${toLua(source.replace(mutation.before,mutation.after))}))()end;`;
  }
  const path=join(directory,'case.lua');writeFileSync(path,`${prelude}dofile('tests/lua/support/deep_breath_vectors.lua')(${toLua(fixture.cases.filter(row=>row.seed===seed))})`);
  return runLua(path);
 }finally{rmSync(directory,{recursive:true,force:true});}
}
export function registerSeed(seed){
 test(`Deep Breath seed ${seed} has source two-stage UID order, complete shuffle owner and one relic callback`,()=>{
  const result=runSeed(seed);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/DEEP_BREATH_SOURCE_PASS/);
 });
}
