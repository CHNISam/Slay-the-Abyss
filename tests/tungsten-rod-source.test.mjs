import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const lock=read('tests/fixtures/tungsten-rod-source.json');
test('Rod locks its fixed source identity and pre-HP ordering independently',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.zipSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(lock.files['relics/TungstenRod.java'].sha256,'690106967f973f2a478b48bb0b5561023474289b99d8a65cd30437e2265fe09a');
 assert.equal(lock.files['characters/AbstractPlayer.java'].sha256,'2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95');
 assert.equal(lock.files['powers/BufferPower.java'].sha256,'c37a54fe614dd9588e298e9d2de0d283bb45c31b58f8aeae7447676093502b60');
 assert.equal(lock.files['powers/StaticDischargePower.java'].sha256,'93b86d1b514f5da259978d98e45061dc0483ba48fbfd9e09882df6faa15d94ef');
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.deepEqual(lock.contracts.allDamageTypes,['NORMAL','THORNS','HP_LOSS']);
 assert.equal(lock.contracts.positiveLossReduction,1);assert.equal(lock.contracts.staticChecksPreRodPositiveAmount,true);
 assert.equal(lock.contracts.bufferZeroPreventsStatic,true);
 assert.deepEqual(lock.contracts.order,['decrementBlock','onAttackedToChangeDamage (Buffer)','onAttacked (Static)','relic.onLoseHpLast (Rod)','power.onLoseHp','HP/death/Fairy']);
});
test('real definition and manifest join existing normal channels without altering the source Rare mother pool',()=>{
 const rod=read('data/relics.json').relics.find(row=>row.id==='tungsten_rod');
 assert.equal(rod.sourceId,'TungstenRod');assert.equal(rod.rarity,'rare');assert.equal(rod.trigger,'hooks');assert.deepEqual(rod.effects,[]);
 const queues=read('data/catalogs/sts1-relic-queues.json').queues;
 assert.deepEqual(Object.fromEntries(Object.entries(queues).map(([tier,ids])=>[tier,ids.length])),{common:33,uncommon:30,rare:28,shop:17,boss:22});
 const queue=queues.rare;
 assert.equal(queue.length,28);assert.equal(queue.filter(id=>id==='TungstenRod').length,1);
 const row=read('data/release/launch-content.json').relics.find(row=>row.id===rod.id);
 assert.equal(row.sourceId,rod.sourceId);assert.deepEqual(row.channels,['treasure','shop_relic']);assert.match(row.naturalExecutionLimitation,/platform\/live acceptance remain pending/);
 assert.equal(read('data/presentation/ui_theme.json').icon.relic.tungsten_rod.placeholder,true);
});
