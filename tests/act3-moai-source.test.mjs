import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const lock=JSON.parse(readFileSync('tests/fixtures/act3-moai-source.json','utf8'));
const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
test('Moai locks actual fixed ZIP members independently of older source-lock history',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(Object.fromEntries(Object.entries(lock.files).map(([name,row])=>[name,row.sha256])),{
  "events/beyond/MoaiHead.java": "dfe22d211e8d7edb95ed0e75aa6b177bb5f2282164be52231b8f44412c0bfa42",
  "core/AbstractCreature.java": "3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b",
  "characters/AbstractPlayer.java": "2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95",
  "relics/GoldenIdol.java": "063065e1da41f27eb786b89935bd0ec32be4c7e93b59fa693eb2c92a3bb16dd4",
  "relics/AbstractRelic.java": "e4b5a8e6dda41cb9b25f75c5777f03e84da245247d1dac5d3070727fc8d24167",
  "relics/MarkOfTheBloom.java": "bf653a5008278992d62d8fa57a4ed1333a274e7b79395ee09c0f9d6979653434",
  "relics/MagicFlower.java": "e3940116e47e36eb3eea9f048a1808ffe2f8b6654db9e30cab9cce8496054eaf",
  "potions/FairyPotion.java": "c292f97254f11ca34e0792b3899be966418d32ea5e8ce3e18cbcbaa5f4500e25",
  "relics/Ectoplasm.java": "717861865521c87b8b3dfbfd94a33a336ee968ce728a1f011f87dafb9471a7d7",
  "dungeons/TheBeyond.java": "dbc559c7a80e98197f0d9d61e76cffa737dab9a9f21981bc535671523152d46b"
});
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.equal(lock.contracts.gold,333);assert.equal(lock.contracts.canonicalRelicId,'golden_idol');assert.equal(lock.contracts.halfHealthEligibility,false);
 assert.deepEqual(lock.contracts.initialChoices,['heal','give_idol','leave']);assert.deepEqual(lock.contracts.resultChoices,['leave']);
});
test('independent float32/Java round oracle retains the conversion boundary and unchanged source seed32',()=>{
 for(const row of lock.roundingOracle)assert.equal(Math.floor(Math.fround(Math.fround(row.maxHp)*Math.fround(.125))+.5),row.loss);
 assert.equal(lock.roundingOracle.find(row=>row.maxHp===16777219).loss,2097153);
 assert.equal(Math.round(16777219*.125),2097152);
 assert.equal(lock.naturalRoute.runSeed,'32');assert.equal(lock.naturalRoute.selectionIndex,2);
 assert.equal(lock.naturalRoute.eventRng.counter,1);assert.equal(lock.naturalRoute.selectionRng.counter,3);
});
test('Moai inventory records actual GoldenIdol dependency evidence while preserving original source-lock history',()=>{
 const row=manifest.events.find(row=>row.originalId==='The Moai Head');assert.equal(row.id,'moai_head');assert.equal(row.act,3);
 assert.equal(row.source,'src/lua/abyss_moai_event.lua');assert.equal(row.poolMode,'explicit-only');assert.deepEqual(row.channels,['explicit:Nodes.enter']);
 assert.match(row.naturalAcquisitionLimitation,/goldenIdol profile/);assert.match(lock.unimplementedDependency,/canonical held-owner fixture/);
 const profile=manifest.profiles[row.profile];assert.equal(profile.local.testFiles.length,4);
 assert.equal(profile.platform.evidence.length,0);assert.equal(profile.live.evidence.length,0);
});
