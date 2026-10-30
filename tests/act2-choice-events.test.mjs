import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/act2-choice-events-source-contract.json','utf8'));
test('four missing original Act2 choice events pin costs, queues, real cards/relics and command boundaries',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(source.sources.length,16);
 assert.deepEqual(source.sources.filter(x=>x.path.startsWith('events/')).map(x=>x.gitBlobSha),[
  '86073de0f401a04100988a648dffa87ad98da14b','71a64d99de1ffd3a598c12bd90594d41c3134749',
  'db226367fbdd0c9f522b0ccab07cf810e9423daa','93701f68f89eb014c0331c25f5c966c847dc37ff']);
 for(const row of source.sources){assert.match(row.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(row.sha256,/^[a-f0-9]{64}$/);assert.ok(row.size>0);assert.ok(row.url.includes(`/blob/${source.sourceCommit}/`));}
 assert.deepEqual(source.behavior.cursed_tome.hpLossCommands,[0,1,2,3,10]);
 assert.deepEqual(source.behavior.cursed_tome.bookOrder,['Necronomicon','Enchiridion',"Nilry's Codex"]);
 assert.deepEqual(source.behavior.forgotten_altar.shedBloodOrder,['increaseMaxHp5AndHeal','NORMAL cached damage']);
 assert.deepEqual(source.behavior.drug_dealer.transformOrder,['first remove','first misc transform','second remove','second misc transform','first delayed obtain','second delayed obtain']);
 assert.match(source.behavior.drug_dealer.purgeable,/bottles included/);assert.match(source.behavior.vampires.obtain,/five fresh Bite/);
 assert.match(source.boundaries,/not natural pool\/native/);
});
for(const [name,count]of [['cursed_tome',5],['forgotten_altar',6],['drug_dealer',6],['vampires',7]]){
 test(`${name}: source-locked staged room through actual Nodes commands`,()=>{
  const result=runLua(`tests/lua/${name}_event.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`${name.toUpperCase()}_EVENT ${count} passed`));
 });
}
