import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const sha=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
const lock=read('tests/fixtures/tomb-red-mask-source.json');
test('Tomb and Red Mask retain fixed raw source facts and exact special obtain/weak timing',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.archiveSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(lock.files['events/beyond/TombRedMask.java'].sha256,'515880ea139fc92c80f42ae6c7e026ddac23eff0c3dd07891ab687c5d4612053');
 assert.equal(lock.files['relics/RedMask.java'].sha256,'870885c0415d842394a8ed487570ce11429b43f951afc96cd523593f1125cb82');
 assert.equal(Object.keys(lock.files).length,12);
 for(const [name,row]of Object.entries(lock.files)){assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);assert.match(row.sha256,/^[a-f0-9]{64}$/);}
 assert.equal(lock.contracts.goldReward,222);assert.equal(lock.contracts.payment,'all current gold, including zero');assert.equal(lock.contracts.relicTier,'SPECIAL');assert.equal(lock.contracts.goldIsRewardItem,false);
 assert.equal(lock.contracts.opening,'BOTTOM per-monster Weak1 with isSourceMonster=false');
 for(const key of ['constructorMiscDraws','choiceRngDraws','namedRelicPoolDraws'])assert.equal(lock.contracts[key],0);
});
test('independent source interpretation pins six gold boundaries and exact full-pool seed14 streams',()=>{
 assert.equal(sha(lock.oracle.generator),lock.oracle.generatorSha256LF);assert.equal(sha('tests/fixtures/tomb-red-mask-vectors.lua'),lock.oracle.fixtureSha256LF);
 const v=read('tests/fixtures/tomb-red-mask-vectors.json');assert.equal(v.natural.seed,'14');assert.equal(v.natural.zeroBasedIndex,5);
 assert.deepEqual(v.natural.eventRng,{words:['1212b40cf65e84d0','77b7a35e647db2d7'],counter:1});
 assert.deepEqual(v.natural.selectionRng,{words:['63de3239da6caeb1','bb5bc3e4ecde15ee'],counter:3});assert.equal(v.natural.miscRng.counter,0);
 assert.equal(v.cases.length,6);for(const row of v.cases){assert.equal(row.resultMask,true);assert.equal(row.resultGold,row.choice==='pay'?0:row.gold+(row.ectoplasm?0:222));}
});
test('actual named SPECIAL binding remains outside every ordinary source queue with honest event/UI evidence',()=>{
 const d=read('data/relics.json').relics.find(row=>row.id==='red_mask');assert.equal(d.sourceId,'Red Mask');assert.equal(d.rarity,'special');assert.equal(d.trigger,'hooks');assert.deepEqual(d.effects,[]);
 const source=read('data/catalogs/sts1-relic-queues.json');for(const ids of Object.values(source.queues))assert.ok(!ids.includes('Red Mask'));
 const catalog=read('docs/rules/evidence/sts1-relic-pool-catalog.json');assert.equal(catalog.registrationOrder.length,149);const bound=catalog.relics.find(row=>row.id==='Red Mask');assert.equal(bound.projectId,'red_mask');assert.equal(bound.scope,'later-act-only');
 const manifest=read('data/release/launch-content.json');const event=manifest.events.find(row=>row.originalId==='Tomb of Lord Red Mask');assert.equal(event.id,'tomb_red_mask');assert.equal(event.act,3);assert.equal(event.poolMode,'explicit-only');assert.deepEqual(event.choices,['wear','pay','leave']);
 assert.deepEqual(manifest.relics.find(row=>row.id==='red_mask').channels,['explicit_event:tomb_red_mask:pay']);
 const p=manifest.profiles[event.profile];assert.equal(p.local.testFiles.length,8);assert.deepEqual(p.platform.evidence,[]);assert.deepEqual(p.live.evidence,[]);assert.match(p.limitation,/Masked Bandits/);
 assert.equal(read('data/presentation/ui_theme.json').icon.relic.red_mask.placeholder,true);assert.equal(read('data/rules.json').events.poolMode,'restricted-seven');
});
