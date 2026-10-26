import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const lock=read('tests/fixtures/toxic-egg-source.json');
test('Toxic Egg pins the seven actual fixed source members and narrow ownership contract',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.zipSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(Object.keys(lock.files).length,7);
 assert.equal(lock.files['relics/ToxicEgg2.java'].sha256,'1149dee0de59c4bd756bf453daf62ecd4dba8e593193d08c941c6ac42445155d');
 for(const [name,row]of Object.entries(lock.files)){
  assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);assert.match(row.sha256,/^[a-f0-9]{64}$/);
 }
 assert.equal(lock.contracts.onEquipOwner,'combatRewardScreen.rewards.cards');
 assert.deepEqual(lock.contracts.onEquipDoesNotVisit,['masterDeck','shop','directDreamCatcherList','combatGeneration']);
 assert.equal(lock.contracts.requiresNotUpgraded,true);assert.equal(lock.contracts.requiresCanUpgrade,true);
 assert.equal(lock.contracts.randomDraws,0);assert.equal(lock.contracts.ordinaryUpgradeRollPrecedesPreview,true);
 assert.equal(lock.contracts.ordinarySuccessfulUpgradeSkipsPreview,true);
});
test('real Toxic Egg identity, manifest and source max-floor join the unchanged complete relic mother queues',()=>{
 const egg=read('data/relics.json').relics.find(r=>r.id==='toxic_egg');
 assert.equal(egg.sourceId,'Toxic Egg 2');assert.equal(egg.rarity,'uncommon');assert.equal(egg.trigger,'hooks');assert.deepEqual(egg.effects,[]);
 const catalog=read('data/catalogs/sts1-relic-queues.json');
 assert.deepEqual(Object.fromEntries(Object.entries(catalog.queues).map(([k,v])=>[k,v.length])),{common:33,uncommon:30,rare:28,shop:17,boss:22});
 assert.equal(catalog.queues.uncommon.filter(id=>id===egg.sourceId).length,1);
 assert.deepEqual(catalog.spawnGates[egg.sourceId],{kind:'max-floor',floor:48,endlessBypass:true});
 const manifest=read('data/release/launch-content.json').relics.find(r=>r.id==='toxic_egg');
 assert.equal(manifest.sourceId,egg.sourceId);assert.deepEqual(manifest.channels,['treasure','shop_relic']);
 assert.match(manifest.naturalExecutionLimitation,/platform\/live acceptance remain pending/);
 assert.equal(read('data/presentation/ui_theme.json').icon.relic.toxic_egg.placeholder,true);
 for(const id of ['molten_egg','frozen_egg','question_card','busted_crown','singing_bowl'])assert.ok(!read('data/relics.json').relics.some(r=>r.id===id));
});
