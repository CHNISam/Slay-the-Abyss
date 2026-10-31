import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-card-random-chain.json'));
test('independent shared card-random source fixture regenerates byte for byte',()=>{
 execFileSync('python',['tools/oracles/sts1_card_random_chain.py','--check']);
});
for(const sample of fixture.cases)test(`shared cardRandomRng preserves Spoon/Branch/Hand/Discovery/Elixir/Snecko identities and every draw seed ${sample.seed}`,()=>{
 const dir=mkdtempSync(join(tmpdir(),'card-random-chain-'));
 try{
  const path=join(dir,'case.lua');writeFileSync(path,`dofile('tests/lua/support/card_random_chain.lua')(${toLua(sample)},${toLua(fixture.fullPool)},${toLua(fixture.attackPool)})`);
  const r=runLua(path);assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/CARD_RANDOM_CHAIN_PASS/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});

test('shared chain rejects removal of Discovery retrieval draws',()=>{
 const dir=mkdtempSync(join(tmpdir(),'card-random-chain-mutant-'));
 try{
  const source=readFileSync('src/lua/abyss_potion_discovery.lua','utf8');
  const target=' generate(combat,state,p.effect)';assert.equal(source.split(target).length,2);
  const module=join(dir,'abyss_potion_discovery.lua');writeFileSync(module,source.replace(target,'    -- mutation: omit unused retrieval group'));
  const sample=fixture.cases[1],path=join(dir,'case.lua');
  writeFileSync(path,`package.loaded.abyss_potion_discovery=dofile(${JSON.stringify(module)});dofile('tests/lua/support/card_random_chain.lua')(${toLua(sample)},${toLua(fixture.fullPool)},${toLua(fixture.attackPool)})`);
  const r=runLua(path);assert.notEqual(r.status,0,r.stdout+r.stderr);assert.match(r.stderr,/discovery_resolve complete stream/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
