import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {validateLaunchContent} from '../scripts/verify-launch-content.mjs';
const lock=JSON.parse(readFileSync('tests/fixtures/sensory-stone-source.json'));
const vectors=JSON.parse(readFileSync(lock.oracle.vectors));
const manifest=JSON.parse(readFileSync('data/release/launch-content.json'));
test('Sensory Stone pins67 actual fixed ZIP members including35 complete ordinary source definitions',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.archiveSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.deepEqual(Object.fromEntries(Object.entries(lock.files).map(([n,r])=>[n,r.sha256])),{
  "events/beyond/SensoryStone.java": "888b2ea6836850e5b04be7e1c24bfe188a161cebd3b868ce9f7a4b906aba0b61",
  "dungeons/AbstractDungeon.java": "8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26",
  "dungeons/TheBeyond.java": "dbc559c7a80e98197f0d9d61e76cffa737dab9a9f21981bc535671523152d46b",
  "cards/AbstractCard.java": "bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61",
  "cards/CardGroup.java": "03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8",
  "rewards/RewardItem.java": "4287fb3caf3a6ad04fd7c09d1d272bc7e98ceecf4a4d599131c3a68467f75859",
  "rooms/AbstractRoom.java": "020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05",
  "screens/CardRewardScreen.java": "6883c6684c11f15b6e3a10466813b01354b05a41d33379e6a084da3ada429aae",
  "screens/CombatRewardScreen.java": "7929ca75599e96c076f9abe2c90576a606c87984174328d10533ada8ee37e70b",
  "ui/buttons/SkipCardButton.java": "73cd265d97f6d6e66e8878e536cf7f6ecfb9b25a1aca620b464af89d4605e7f2",
  "ui/buttons/ProceedButton.java": "8f61b7490806dcfee1c53552753fcbf0e510db0fe7b1c45fa7ae838198b0e4d4",
  "events/AbstractEvent.java": "4527717d367f8f7e9a11bb3be30361ffaa92aff1b49e581ce060b179b0797c13",
  "events/AbstractImageEvent.java": "438f8c014c563c51f2f14d8f98839e71a7c4a45db314d9b36be8c76ba0b2d92f",
  "characters/AbstractPlayer.java": "2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95",
  "core/AbstractCreature.java": "3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b",
  "cards/DamageInfo.java": "cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a",
  "random/Random.java": "476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172",
  "relics/AbstractRelic.java": "e4b5a8e6dda41cb9b25f75c5777f03e84da245247d1dac5d3070727fc8d24167",
  "relics/QuestionCard.java": "ef7faee05ad55e0d90f3f8e850641f36a549054c02a302bfcc4c9a5c718db608",
  "relics/BustedCrown.java": "d5898ec2c64b3d3ec0d0c3e7f244e41ec1b77aeba3b69ff4c8da991859fb9d5d",
  "relics/ToxicEgg2.java": "1149dee0de59c4bd756bf453daf62ecd4dba8e593193d08c941c6ac42445155d",
  "relics/MoltenEgg2.java": "415e68f17fd5fa4fb123344341c12adfa8318bc6a942c9c283f38341b035183f",
  "relics/FrozenEgg2.java": "0f6c1e60f11ff22d6fa343128d1740947a6a53efb2042f76782a2d1dbf6b8c2e",
  "relics/SingingBowl.java": "20d70521e99d435b8c732b2b4988113f95578e401e45dcfdacd50001d7933c72",
  "relics/TungstenRod.java": "690106967f973f2a478b48bb0b5561023474289b99d8a65cd30437e2265fe09a",
  "relics/LizardTail.java": "9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90",
  "relics/MarkOfTheBloom.java": "bf653a5008278992d62d8fa57a4ed1333a274e7b79395ee09c0f9d6979653434",
  "potions/FairyPotion.java": "c292f97254f11ca34e0792b3899be966418d32ea5e8ce3e18cbcbaa5f4500e25",
  "relics/CeramicFish.java": "bf8a18d2488d17304a0c9bd153c42898065aa00cbecb424cd1e59e66b2d6fa1c",
  "vfx/FastCardObtainEffect.java": "a7d13ed7aed4d76741deb6221d110434c2dc892e912a459aa1b9a44e3408cf80",
  "cards/Soul.java": "8e4105a9df83d93ad4f66d35c54b63720e90f71b80c7594a6faa454d19b545c0",
  "cards/SoulGroup.java": "c3b44b69f2ebcff77b8a1d49c492973900cc42d597d66c651c4f41399af031cb",
  "cards/colorless/Apotheosis.java": "3b2f0790490d976fc7383ec52ddf8a0a8670aad94b6114c409e2ed7cf3c08919",
  "cards/colorless/BandageUp.java": "a4f9e85f0c3eae7b8e732e51cee58e8eddf51d36fcc22ee285fbff50ff89b41c",
  "cards/colorless/Blind.java": "fa6642c910634efd6c5400ec1b1635b1d3730d2997ab560eb9ae3e8079c69192",
  "cards/colorless/Chrysalis.java": "42841aaf490e6fa49b945b474421a8fa09b2780afd18305a62ca9037b9cce9b0",
  "cards/colorless/DarkShackles.java": "6abe903f05221383909c27f4802f90a4dceda5d61b63a3e0e5ab378227076a9f",
  "cards/colorless/DeepBreath.java": "53a9ccecf580f8b984f28689ae7eb8709e3cbb25dcfe044e567c67bce83fe4e3",
  "cards/colorless/Discovery.java": "4c04d50f3fdef0bdfc6c97c140732c2c53982112f9845334041d5b79a48958e2",
  "cards/colorless/DramaticEntrance.java": "5ccfb9aebbc04fbd5a74dd9a885ad65f29213d1424879b521f2d49f6d01d2513",
  "cards/colorless/Enlightenment.java": "496d3cf18834aedf52969ba502dc2473a1f78ad951b725a0424744e48cf280e5",
  "cards/colorless/Finesse.java": "035d948e5f0076a53f814014168438df48b01a7aeef94ef86b46d6bc5ee4a7fa",
  "cards/colorless/FlashOfSteel.java": "882b0c247728ccf5e9fc0f3ca4fc91cb0671e3b5061ef0bb5ecb70bfbd6c388c",
  "cards/colorless/Forethought.java": "be7e7dfe4481677d32bee6d61af231a135cb75d723b4f3a81767c522e5edd42a",
  "cards/colorless/GoodInstincts.java": "84e576bc414bfe821c9c6d1af881e0ce0e451cc439e77ec70008a2f83e60ca38",
  "cards/colorless/HandOfGreed.java": "7d1beccd4c06a7004cc896c5a875f7bafdf55eab542703f6bd179a7300fe10bb",
  "cards/colorless/Impatience.java": "c6d3c985affced6ac1042c63aa5f1ca759552761c325c152bcaa3db87b07e4f6",
  "cards/colorless/JackOfAllTrades.java": "69783d064c8a9f2f30011e0f0f8585d6ed1ba16dd184b0751a1bd6d92d268d62",
  "cards/colorless/Madness.java": "3f406e941ea2bb2bb4f28de7cc608c047db711aef029cb44de0111303f744013",
  "cards/colorless/Magnetism.java": "cae19a397b4658ab3fe44ca932b33ab8f03190f5ba1b497137da7c78a9e127a6",
  "cards/colorless/MasterOfStrategy.java": "984a5b530837cc56565dff77ee0eb721a86f7bbb7f9fd06eb4fcda4ffd42d392",
  "cards/colorless/Mayhem.java": "005101e74342b3c4c512fe27d07382bacd9f21e7e437ed749cf7a9e7e0788667",
  "cards/colorless/Metamorphosis.java": "afb75e53d82624530525407f0462b6f765ae17ba4ad85667737da7846337677e",
  "cards/colorless/MindBlast.java": "823333dc82f10f80a2a2dc355ca3a43e714ea261adb8e6dd7b442d32c0563cd5",
  "cards/colorless/Panacea.java": "5042be2b1a4d9b2393baf518bd6bdcefa63dae8d5f3c6ce85dde2e08a3b86a47",
  "cards/colorless/Panache.java": "3e6b8c118ad93e4647c45b869fbd1dcf054fcca41369132131d324932c7c38ba",
  "cards/colorless/PanicButton.java": "8949ca19ac7985352bc8470f05e6a1b01cfd022bb3838faeb44a306ed72c5938",
  "cards/colorless/Purity.java": "263fab7faf5eed0ccbcebd1938d71d37211753ae32365fb4ac2d684402eb234e",
  "cards/colorless/SadisticNature.java": "b486cbffe838bb70a86671e2348035a30f12086a121eed370678f2665fd9acab",
  "cards/colorless/SecretTechnique.java": "46f62e4da6f86f6ba9e36a1ede06b6e0f58588aa668e77b65a7c05bb28f98de2",
  "cards/colorless/SecretWeapon.java": "34dc60ddebbb6c46548579b21daaffb09aec995b57f69eeff4b64335e6b936be",
  "cards/colorless/SwiftStrike.java": "bb3c6c9a3c39446365930489cd1b00d6a46f4840be543344a40ecdee7440f2c2",
  "cards/colorless/TheBomb.java": "2eb463ade40d2911e3e0d2b3e944bcc8d56e5a5997a3edbcdfda061e6d9137aa",
  "cards/colorless/ThinkingAhead.java": "0261807485a7e39dc6affbc23acd2f9a940893f3bbf82c09523982d11ee7b246",
  "cards/colorless/Transmutation.java": "d7dde0b842cc671083e41cbbd31071adf02b63e29a33c401cdd17a137a74f1ee",
  "cards/colorless/Trip.java": "10044017470dc9cb1bbaf956aa30290935294e69e98ebbdd264df5c4241a740e",
  "cards/colorless/Violence.java": "55e00b1e59462445c7d9a4353f9151ef1dcb88c565f09eb6a0d8508f5502361d"
}
 );
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.equal(lock.contracts.damageType,'HP_LOSS');assert.equal(lock.contracts.damageOwner,null);assert.equal(lock.contracts.damageAfterAllRewards,true);
 assert.equal(lock.contracts.poolSize,35);assert.equal(lock.contracts.upgradeRolls,0);assert.equal(lock.contracts.rareResetsOffset,5);
 assert.equal(lock.contracts.rareChance,Math.fround(.3));
 assert.deepEqual(lock.contracts.choices,{one:{groups:1,damage:0},two:{groups:2,damage:5},three:{groups:3,damage:10}});
});
test('independent Python oracle retains complete source order, float/index retries and no production imports',()=>{
 const script=readFileSync(lock.oracle.script,'utf8').replaceAll('\r\n','\n');assert.equal(createHash('sha256').update(script).digest('hex'),lock.oracle.normalizedLfSha256);
 const checked=spawnSync('python',[lock.oracle.script,'--check'],{encoding:'utf8',timeout:5000});assert.equal(checked.status,0,checked.stderr);assert.match(checked.stdout,/15 cases/);
 assert.equal(vectors.cases.length,15);assert.equal(vectors.pools.uncommon.length,20);assert.equal(vectors.pools.rare.length,15);
 assert.ok(vectors.cases.some(c=>c.trace.some(t=>t.indices.length>1)));
 assert.ok(vectors.cases.some(c=>c.finalOffset===-17));assert.ok(vectors.cases.some(c=>c.finalOffset===5));
 for(const c of vectors.cases){assert.equal(c.miscRng.counter,1);assert.equal(c.cardRng.counter,c.trace.length+c.trace.reduce((n,t)=>n+t.indices.length,0));for(const g of c.groups)assert.equal(new Set(g).size,3);}
 assert.ok(vectors.cases.some(c=>c.groups.flat().includes('Bandage Up')));assert.ok(vectors.cases.some(c=>c.groups.flat().includes('HandOfGreed')));
 const registration=JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json')).registration;
 for(const rarity of ['uncommon','rare'])assert.deepEqual(vectors.pools[rarity],registration.filter(r=>r.color==='COLORLESS'&&r.rarity===rarity.toUpperCase()).map(r=>r.id).sort());
});
test('only35 ordinary colorless cards gain the explicit event channel; all evidence remains local',()=>{
 const row=manifest.events.find(r=>r.id==='sensory_stone');assert.equal(row.originalId,'SensoryStone');assert.equal(row.act,3);assert.equal(row.poolMode,'explicit-only');assert.deepEqual(row.stages,['intro','choice','rewards','cards','result']);
 assert.equal(manifest.sharedCards.filter(r=>r.channels.includes('explicit_event:sensory_stone:card_reward')).length,35);
 assert.ok(manifest.sharedCards.filter(r=>r.rarity==='special').every(r=>!r.channels.includes('explicit_event:sensory_stone:card_reward')));
 const p=manifest.profiles.sensoryStone;assert.equal(p.local.testFiles.length,9);assert.deepEqual(p.platform.evidence,[]);assert.deepEqual(p.live.evidence,[]);
 const broken=structuredClone(manifest);broken.sharedCards.find(r=>r.id==='bandage_up').channels=broken.sharedCards.find(r=>r.id==='bandage_up').channels.filter(c=>!c.includes('sensory_stone'));
 assert.ok(validateLaunchContent(broken,{runtime:false}).some(e=>e.includes('sharedCards/bandage_up channels')));
 assert.equal(lock.dependency.originalCommit,'ff01ba077b5c61881b87c8bc3e4436793c728a0f');assert.ok(lock.missingDependencies.some(s=>s.includes('lizard_tail')));
});
