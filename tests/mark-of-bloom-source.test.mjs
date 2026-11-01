import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const json=p=>JSON.parse(readFileSync(p,'utf8'));
test('Mark fixed mirror lock records the real heal override, maxHP and Fairy boundaries',()=>{
 const lock=json('tests/fixtures/mark-of-bloom-source.json');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.archiveSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(lock.files['relics/MarkOfTheBloom.java'].sha256,'bf653a5008278992d62d8fa57a4ed1333a274e7b79395ee09c0f9d6979653434');
 assert.equal(Object.keys(lock.files).length,16);
 for(const [path,row] of Object.entries(lock.files)){
  assert.equal(row.member,`sts-${lock.sourceCommit}/${path}`);assert.match(row.sha256,/^[a-f0-9]{64}$/);
 }
 assert.equal(lock.facts.onPlayerHeal,0);assert.equal(lock.facts.tier,'SPECIAL');
 assert.equal(lock.facts.maximumHpIncrease,true);assert.equal(lock.facts.maximumHpAssociatedHealing,0);
 assert.equal(lock.facts.fairyRevival,false);assert.equal(lock.facts.fairyConsumedWhileBlocked,false);
 assert.equal(lock.facts.enemyHealingAffected,false);assert.equal(lock.boundaries.platform,'not_run');assert.equal(lock.boundaries.live,'not_run');
});
test('Mark is one legal SPECIAL binding outside every ordinary relic queue and keeps honest acquisition evidence',()=>{
 const relics=json('data/relics.json').relics;
 const mark=relics.find(r=>r.id==='mark_of_bloom');assert.ok(mark,'Mark SPECIAL definition required');
 assert.equal(mark.sourceId,'Mark of the Bloom');assert.equal(mark.rarity,'special');assert.equal(mark.trigger,'hooks');assert.deepEqual(mark.effects,[]);
 assert.equal(relics.filter(r=>r.sourceId==='Mark of the Bloom').length,1);
 const pools=json('data/catalogs/sts1-relic-queues.json');for(const ids of Object.values(pools.queues))assert.ok(!ids.includes(mark.sourceId));
 const ledger=json('docs/rules/evidence/sts1-relic-pool-catalog.json');const row=ledger.relics.find(r=>r.id===mark.sourceId);
 assert.equal(ledger.registrationOrder.length,149);assert.equal(ledger.summary.queue,130);assert.equal(ledger.summary.queueMissing,83);assert.equal(ledger.summary.act1Missing,88);
 assert.equal(row.projectId,mark.id);assert.equal(row.scope,'later-act-only');assert.deepEqual(row.channels,[]);
 const manifest=json('data/release/launch-content.json');const entry=manifest.relics.find(r=>r.id===mark.id);
 assert.deepEqual(entry.channels,['explicit_event:mind_bloom:upgrade']);
 assert.match(entry.naturalAcquisitionLimitation,/pending/);assert.equal(manifest.profiles.mark.platform.evidence.length,0);assert.equal(manifest.profiles.mark.live.evidence.length,0);
 assert.equal(json('data/presentation/ui_theme.json').icon.relic.mark_of_bloom.placeholder,true);
 assert.deepEqual(validateContent(loadContent('data')),[]);
 const bad=loadContent('data');bad.relics.relics.find(r=>r.id===mark.id).id='unknown_mark_hook';
 assert.ok(validateContent(bad).some(error=>error.includes('unsupported relic hook')));
});
