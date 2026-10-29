import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync}from'node:fs';
import {createHash}from'node:crypto';
import {spawnSync}from'node:child_process';
import {javaShuffle,tiers}from'../tools/oracles/sts1_relic_queues.mjs';
import {buildLuaData}from'../scripts/build-lua-data.mjs';
import {runLua}from'../scripts/test-lua.mjs';
const json=p=>JSON.parse(readFileSync(p,'utf8'));
const sha=p=>createHash('sha256').update(readFileSync(p,'utf8').replaceAll('\r\n','\n')).digest('hex');
const lock=json('tests/fixtures/max-hp-relics-source.json'),vectors=json('tests/fixtures/max-hp-relics-vectors.json');
test('fixed-source max HP identities, rarity, truthful full catalogue and unaccepted platform/live records',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');assert.equal(Object.keys(lock.files).length,9);
 const relics=json('data/relics.json').relics,inventory=json('data/release/launch-content.json');
 const catalog=json('docs/rules/evidence/sts1-relic-pool-catalog.json');
 for(const[id,fact]of Object.entries(lock.facts)){
  const definition=relics.find(d=>d.id===id);assert.equal(definition?.sourceId,fact.sourceId);assert.equal(definition.rarity,fact.rarity);
  assert.equal(definition.trigger,'hooks');assert.deepEqual(definition.effects,[]);
  const row=catalog.relics.find(d=>d.id===fact.sourceId);assert.equal(row.projectId,id);assert.equal(row.status,'existing-local-effect-not-full-pool-parity');
  if(id!=='strawberry'){
   const entry=inventory.relics.find(d=>d.id===id);assert.equal(entry?.profile,'maxHpRelics');
   assert.equal(inventory.profiles[entry.profile].live.status,'pending-natural-acquisition-and-execution');
   if(id==='lees_waffle')for(const catalog of [json('data/catalogs/sts1-relic-queues.json'),...Object.values(json('data/catalogs/sts1-class-relic-queues.json'))]){
    assert.ok(catalog.queues.shop.includes(fact.sourceId));for(const tier of ['common','uncommon','rare','boss'])assert.ok(!catalog.queues[tier].includes(fact.sourceId));
   }
  }
 }
});
test('independent source-method numeric and full-queue inputs reproduce without production imports',()=>{
 assert.equal(sha('tools/oracles/sts1_max_hp_relics.py'),vectors.generatorSha256);
 assert.equal(sha('tests/fixtures/max-hp-relics-vectors.lua'),vectors.luaSha256);
 for(const[p,hash]of Object.entries(vectors.inputs))assert.equal(sha(p),hash,p);
 const catalogs={ironclad:json('data/catalogs/sts1-relic-queues.json'),...json('data/catalogs/sts1-class-relic-queues.json')};
 for(const row of vectors.cases.channels)for(const[i,tier]of tiers.entries())assert.deepEqual(row.queues[tier],javaShuffle(catalogs[row.character].queues[tier],row.rawLongHex[i]));
 const result=spawnSync('python',['-X','utf8','tools/oracles/sts1_max_hp_relics.py','--check'],{encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/160 health; 28 full source channel cases/);
});
for(const[fixture,marker]of [['health','HEALTH_PASS 11'],...['ironclad','silent','defect','watcher'].map(c=>[c,'CHANNELS_PASS '+c+' 7'])]){
 test(`max HP relic source ${fixture}`,()=>{
  buildLuaData();const result=runLua(`tests/lua/max_hp_relics_${fixture}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp('MAX_HP_RELICS_'+marker));
 });
}
