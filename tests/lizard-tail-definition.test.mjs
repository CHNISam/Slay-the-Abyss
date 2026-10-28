import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadContent} from '../scripts/validate-data.mjs';
const bundle=loadContent('data');
test('Lizard Tail is exactly the fixed-source rare hook with no generic combat effects',()=>{
 const rows=bundle.relics.relics.filter(row=>row.id==='lizard_tail');
 assert.equal(rows.length,1,'LIZARD_TAIL_DEFINITION_MISSING');
 const {id,sourceId,name,description,rarity,trigger,effects,...other}=rows[0];
 assert.deepEqual({id,sourceId,rarity,trigger,effects},
  {id:'lizard_tail',sourceId:'Lizard Tail',rarity:'rare',trigger:'hooks',effects:[]});
 assert.deepEqual(other,{});assert.equal(name,'蜥蜴尾巴');
 assert.match(description,/一半/);assert.match(description,/向下取整/);assert.match(description,/一次/);
 const lock=JSON.parse(readFileSync('tests/fixtures/lizard-tail-source.json','utf8'));
 assert.equal(lock.files['relics/LizardTail.java'].sha256,'9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90');
 assert.equal(sourceId,lock.contracts.sourceId);assert.equal(rarity,lock.contracts.rarity);
});
test('the isolated callback is classified in the existing core architecture entry point',()=>{
 const architecture=JSON.parse(readFileSync('config/architecture.json','utf8'));
 assert.equal(architecture.layers.abyss_lizard_tail,'core');
 assert.ok(readFileSync('src/lua/abyss_lizard_tail.lua','utf8').includes('function M.tryRevive'));
});
test('all four unfiltered source queues retain the single original rare Lizard Tail identity',()=>{
 const sources=[bundle.relicSource,...Object.values(bundle.classRelicSources)];
 assert.equal(sources.length,4);
 for(const source of sources){
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.equal(source.queues.rare.filter(id=>id==='Lizard Tail').length,1);
  for(const [tier,ids]of Object.entries(source.queues))if(tier!=='rare')assert.ok(!ids.includes('Lizard Tail'));
 }
});
