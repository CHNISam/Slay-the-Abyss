import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const lock=JSON.parse(readFileSync('tests/fixtures/golden-idol-source.json'));
const manifest=JSON.parse(readFileSync('data/release/launch-content.json'));
test('Golden Idol locks raw ZIP members and exact acquire/trap/offer timing independently',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(Object.fromEntries(Object.entries(lock.files).map(([k,v])=>[k,v.sha256])),{
  "events/exordium/GoldenIdolEvent.java": "3b3cab0799bb027281f7e4784d83efc9c9f6771bf56d039a1d0694e7d02351aa",
  "relics/GoldenIdol.java": "063065e1da41f27eb786b89935bd0ec32be4c7e93b59fa693eb2c92a3bb16dd4",
  "rewards/RewardItem.java": "4287fb3caf3a6ad04fd7c09d1d272bc7e98ceecf4a4d599131c3a68467f75859",
  "rooms/AbstractRoom.java": "020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05",
  "characters/AbstractPlayer.java": "2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95",
  "core/AbstractCreature.java": "3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b",
  "relics/AbstractRelic.java": "e4b5a8e6dda41cb9b25f75c5777f03e84da245247d1dac5d3070727fc8d24167",
  "relics/Circlet.java": "b8038556fcc22e49a8f3489b0f2e79ad69fae10c50500b4863d94e131387652c",
  "cards/curses/Injury.java": "07245c69c17efe1a5768563be1718b9c39fd80c8ba541db14260e6e3d7bc446e",
  "relics/Omamori.java": "9a4ec0639162f5031e74587dcf5ad191209dd92f2063d4747495ccb265d5cf6f",
  "relics/CeramicFish.java": "bf8a18d2488d17304a0c9bd153c42898065aa00cbecb424cd1e59e66b2d6fa1c",
  "relics/DarkstonePeriapt.java": "629f1f8d4bd033da581468b7f4a9a7c63051d3cec6cb8f6d6c0b2e3d3736efde",
  "relics/TungstenRod.java": "690106967f973f2a478b48bb0b5561023474289b99d8a65cd30437e2265fe09a",
  "relics/LizardTail.java": "9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90",
  "relics/Torii.java": "981540a0d16dcfe5f7738b0539c9df603d1ae22fffa93f4b28170d3e737a2e62",
  "potions/FairyPotion.java": "c292f97254f11ca34e0792b3899be966418d32ea5e8ce3e18cbcbaa5f4500e25",
  "relics/Ectoplasm.java": "717861865521c87b8b3dfbfd94a33a336ee968ce728a1f011f87dafb9471a7d7",
  "dungeons/Exordium.java": "93808b9da69b76da6b8f0471cc3533fa113fa28298939bbc48eb55566a976c08",
  "dungeons/AbstractDungeon.java": "8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26",
  "helpers/EventHelper.java": "e4d91b07439a081d5e5730944d601773a844ddd152e85abc72bb3797d777f41b",
  "random/Random.java": "476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172",
  "vfx/cardManip/ShowCardAndObtainEffect.java": "1daffc2b13c79a1ddb10fcce995cf18980e917a576dba6db3751dccffa892e52",
  "cards/DamageInfo.java": "cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a"
}
 );
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.deepEqual(lock.contracts.trapOrder,['injury','damage','max_hp']);assert.equal(lock.contracts.immediateOwner,true);
 assert.equal(lock.contracts.damageType,'NORMAL');assert.equal(lock.contracts.damageOwner,null);
 for(const row of lock.roundingOracle){assert.equal(Math.trunc(Math.fround(Math.fround(row.maxHp)*Math.fround(.25))),row.damage);assert.equal(Math.max(1,Math.trunc(Math.fround(Math.fround(row.maxHp)*Math.fround(.08)))),row.maxLoss);}
 for(const row of lock.goldOracle)assert.equal(Math.floor(Math.fround(Math.fround(row.base)*Math.fround(.25))+.5),row.bonus);
 assert.equal(lock.goldOracle.find(x=>x.base===10).bonus,3);assert.equal(lock.roundingOracle.find(x=>x.maxHp===16777219).damage,4194305);
 assert.equal(lock.naturalRoute.seed,'16');assert.equal(lock.naturalRoute.selectionIndex,2);assert.equal(lock.naturalRoute.eligibleNormalCount,9);
 assert.deepEqual(lock.naturalRoute.eventRng,{words:['ccb954bc7af860a2','2ab98db97070fe1b'],counter:1});
 assert.deepEqual(lock.naturalRoute.selectionRng,{words:['b83dec7de1ade519','4e3c229549c53a82'],counter:3});
});
test('Golden Idol is a real SPECIAL definition with event-only acquisition, separate rounded offer bonus and honest evidence',()=>{
 const def=JSON.parse(readFileSync('data/relics.json')).relics.find(x=>x.id==='golden_idol');assert.equal(def.sourceId,'Golden Idol');assert.equal(def.rarity,'special');assert.equal(def.trigger,'hooks');
 const event=manifest.events.find(x=>x.id==='golden_idol');assert.equal(event.originalId,'Golden Idol');assert.equal(event.poolMode,'explicit-only');assert.deepEqual(event.stages,['intro','trap','result']);
 const relic=manifest.relics.find(x=>x.id==='golden_idol');assert.deepEqual(relic.channels,['explicit_event:golden_idol:take']);
 assert.ok(manifest.relics.find(x=>x.id==='circlet').channels.includes('explicit_event:golden_idol:repeat_take'));
 assert.ok(manifest.generatedCards.find(x=>x.id==='injury').channels.includes('explicit_event:golden_idol:injury'));
 const p=manifest.profiles.goldenIdol;assert.equal(p.local.testFiles.length,9);assert.deepEqual(p.platform.evidence,[]);assert.deepEqual(p.live.evidence,[]);
 assert.match(p.limitation,/currency glyph/);assert.equal(JSON.parse(readFileSync('data/rules.json')).events.poolMode,'restricted-seven');
});
