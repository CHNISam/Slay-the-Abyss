import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const lock=JSON.parse(readFileSync('tests/fixtures/act3-winding-source.json','utf8'));
const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
test('Winding locks the actual fixed ZIP damage/obtain/fatal update chain and refuses unresolved relic hooks',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(Object.fromEntries(Object.entries(lock.files).map(([name,row])=>[name,row.sha256])),{
  "events/beyond/WindingHalls.java": "f419f2ad258121a4970dffd289118a85c23ddd8d5025efa1d4a4f4cdbb001d2b",
  "cards/DamageInfo.java": "cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a",
  "characters/AbstractPlayer.java": "2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95",
  "core/AbstractCreature.java": "3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b",
  "dungeons/AbstractDungeon.java": "8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26",
  "vfx/cardManip/ShowCardAndObtainEffect.java": "1daffc2b13c79a1ddb10fcce995cf18980e917a576dba6db3751dccffa892e52",
  "cards/Soul.java": "8e4105a9df83d93ad4f66d35c54b63720e90f71b80c7594a6faa454d19b545c0",
  "cards/SoulGroup.java": "c3b44b69f2ebcff77b8a1d49c492973900cc42d597d66c651c4f41399af031cb",
  "cards/colorless/Madness.java": "3f406e941ea2bb2bb4f28de7cc608c047db711aef029cb44de0111303f744013",
  "cards/curses/Writhe.java": "9c6b5dfd72225f1500456784fea3268864f8c2b72a9f8bd0fe4ac425714885d8",
  "relics/Omamori.java": "9a4ec0639162f5031e74587dcf5ad191209dd92f2063d4747495ccb265d5cf6f",
  "relics/CeramicFish.java": "bf8a18d2488d17304a0c9bd153c42898065aa00cbecb424cd1e59e66b2d6fa1c",
  "relics/Torii.java": "981540a0d16dcfe5f7738b0539c9df603d1ae22fffa93f4b28170d3e737a2e62",
  "relics/TungstenRod.java": "690106967f973f2a478b48bb0b5561023474289b99d8a65cd30437e2265fe09a",
  "relics/LizardTail.java": "9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90",
  "relics/MagicFlower.java": "e3940116e47e36eb3eea9f048a1808ffe2f8b6654db9e30cab9cce8496054eaf",
  "relics/MarkOfTheBloom.java": "bf653a5008278992d62d8fa57a4ed1333a274e7b79395ee09c0f9d6979653434",
  "potions/FairyPotion.java": "c292f97254f11ca34e0792b3899be966418d32ea5e8ce3e18cbcbaa5f4500e25",
  "relics/ToxicEgg2.java": "1149dee0de59c4bd756bf453daf62ecd4dba8e593193d08c941c6ac42445155d",
  "relics/DarkstonePeriapt.java": "629f1f8d4bd033da581468b7f4a9a7c63051d3cec6cb8f6d6c0b2e3d3736efde"
});
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.equal(lock.contracts.damageType,'NORMAL');assert.equal(lock.contracts.damageOwner,null);assert.equal(lock.contracts.fatalStillObtainsTwoMadness,true);
 assert.deepEqual(lock.contracts.choices,['madness','writhe','max_hp']);
 assert.ok(lock.missingDependencies.some(row=>row.startsWith('tungsten_rod:')));assert.ok(lock.missingDependencies.some(row=>row.startsWith('lizard_tail:')));
});
test('independent float32 and source-RNG contracts keep all three ratios and normal/full source entry',()=>{
 for(const row of lock.roundingOracle)for(const [field,ratio]of [['damage',.125],['heal',.25],['maxLoss',.05]])assert.equal(Math.floor(Math.fround(Math.fround(row.maxHp)*Math.fround(ratio))+.5),row[field]);
 assert.equal(lock.naturalRoute.seed,'11');assert.equal(lock.naturalRoute.selectionIndex,6);assert.equal(lock.naturalRoute.eventRng.counter,1);assert.equal(lock.naturalRoute.selectionRng.counter,3);assert.equal(lock.naturalRoute.miscRng.counter,0);
 const row=manifest.events.find(row=>row.originalId==='Winding Halls');assert.equal(row.id,'winding_halls');assert.equal(row.act,3);assert.equal(row.poolMode,'explicit-only');
 assert.match(row.naturalAcquisitionLimitation,/tungsten_rod\/lizard_tail/);const profile=manifest.profiles[row.profile];assert.equal(profile.local.testFiles.length,7);assert.deepEqual(profile.platform.evidence,[]);assert.deepEqual(profile.live.evidence,[]);
});
