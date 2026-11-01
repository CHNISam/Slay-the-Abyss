import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {javaShuffle,drawRelic,tiers} from '../tools/oracles/sts1_relic_queues.mjs';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const vectors=read('tests/fixtures/sts1-treasure-vectors.json');
test('chest vectors preserve pinned independent generator and primitive identities',()=>{
 const hash=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
 assert.equal(hash('tools/oracles/sts1_treasure.py'),vectors.generatorSha256);
 assert.equal(hash('tools/oracles/sts1_combat_gold.py'),vectors.primitiveGeneratorSha256);
 assert.equal(vectors.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(vectors.cases.length,23);assert.equal(vectors.cases.flatMap(c=>c.steps).length,69);
 const kinds=new Set(vectors.cases.flatMap(c=>c.steps).map(s=>s.kind));assert.deepEqual([...kinds].sort(),['large','medium','small']);
});
test('chest rules, hooks, multi rewards and continuous RNG match independent source vectors',()=>{
 const catalog=read('data/catalogs/sts1-relic-queues.json');
 const queueVectors=read('tests/fixtures/sts1-relic-pool-vectors.json');
 const known=new Map(queueVectors.cases.map(sample=>[sample.seed,sample]));
 const cases=vectors.cases.map(sample=>({...sample,steps:sample.steps.map(step=>({...step}))}));
 const dir=mkdtempSync(join(tmpdir(),'abyss-treasure-'));
 try{
  // Source queues are built independently from Python RandomXS128 words and
  // the established Java Collections shuffle oracle, never production Lua.
  for(const sample of cases){
   if(known.has(sample.seed))assert.deepEqual(sample.shuffleLongHex,known.get(sample.seed).randomLongHex);
   const queues=Object.fromEntries(tiers.map((tier,index)=>[tier,javaShuffle(catalog.queues[tier],sample.shuffleLongHex[index])]));
   for(const step of sample.steps){
    step.relic=drawRelic(queues,step.tier,{eligible:()=>true});step.queues=structuredClone(queues);
   }
  }
  const file=join(dir,'vectors.lua');
  writeFileSync(file,`ABYSS_TREASURE_FIXTURE=${toLua({catalog:{...catalog,spawnGates:{}},cases})}\ndofile('tests/lua/treasure_rewards.lua')\n`);
  const result=runLua(file);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_TREASURE_PASS 10/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
