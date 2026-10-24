import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLaunchContent } from '../scripts/verify-launch-content.mjs';

const fresh = () => JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));
test('frozen inventory matches production data and actual Lua support pools', () => {
  assert.deepEqual(validateLaunchContent(fresh()), []);
});
test('inventory gate rejects missing content, candidate admission and invented live completion', () => {
  const missing = fresh(); missing.cards.pop();
  assert.ok(validateLaunchContent(missing, { runtime: false }).some(error => error.includes('cards')));
  const candidate = fresh(); candidate.events.push({ ...candidate.events[0], id: 'Match and Keep!' });
  assert.ok(validateLaunchContent(candidate, { runtime: false }).some(error => error.includes('excluded content admitted')));
  const falsePass = fresh(); falsePass.profiles.cards.live.status = 'passed';
  assert.ok(validateLaunchContent(falsePass, { runtime: false }).some(error => error.includes('acceptance requires')));
});
test('inventory gate rejects reward/encounter drift and omitted final-floor relic boundary', () => {
  const rarity = fresh(); rarity.cards.find(card => card.id === 'strike').bossReward = true;
  assert.ok(validateLaunchContent(rarity, { runtime: false }).some(error => error.includes('Boss reward rarity')));
  const encounter = fresh(); encounter.encounters[0].enemies = ['guardian'];
  assert.ok(validateLaunchContent(encounter, { runtime: false }).some(error => error.includes('encounters/')));
  const relic = fresh(); delete relic.relics.find(row => row.id === 'sozu').naturalExecutionLimitation;
  assert.ok(validateLaunchContent(relic, { runtime: false }).some(error => error.includes('final-floor')));
});
test('production inventory rejects an unknown card in place of a required card', () => {
  const manifest = fresh();
  manifest.cards.find(row => row.id === 'cleave').id = 'unknown_card';
  assert.ok(validateLaunchContent(manifest).some(error => error.includes('cards')));
});

test('inventory includes and validates the true branch of a dynamic encounter', () => {
  const manifest = fresh();
  const branch = manifest.encounters.find(row => row.id === 'small_slimes');
  delete branch.enemiesOnTrue;
  assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes('enemiesOnTrue')));
  const missingChannel = fresh();
  missingChannel.enemies.find(row => row.id === 'acid_slime_m').channels = ['encounter:medium_slimes'];
  assert.ok(validateLaunchContent(missingChannel, { runtime: false }).some(error => error.includes('enemies/acid_slime_m channels')));
});

test('gremlin launch inventory accepts the four-of-eight production pool without fixed enemies', () => {
  const manifest = fresh();
  const gang = manifest.encounters.find(row => row.id === 'gremlin_gang');
  assert.equal(gang.gremlinCount, 4);
  assert.deepEqual(gang.gremlinPool, [
    'mad_gremlin', 'mad_gremlin', 'sneaky_gremlin', 'sneaky_gremlin',
    'fat_gremlin', 'fat_gremlin', 'shield_gremlin', 'wizard_gremlin',
  ]);
  assert.equal(Object.hasOwn(gang, 'enemies'), false);
  assert.deepEqual(validateLaunchContent(manifest, { runtime: false }), []);
});

test('gremlin launch gate rejects missing, reordered, deduplicated, or wrong-count pool declarations', () => {
  for (const change of [
    row => { delete row.gremlinPool; },
    row => { row.gremlinPool = [...new Set(row.gremlinPool)]; },
    row => { row.gremlinPool = [...row.gremlinPool].reverse(); },
    row => { delete row.gremlinCount; },
    row => { row.gremlinCount = 5; },
  ]) {
    const manifest = fresh();
    change(manifest.encounters.find(row => row.id === 'gremlin_gang'));
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => /encounters\/gremlin_gang\/gremlin(Pool|Count)/.test(error)));
  }
});

test('gremlin launch gate rejects a stale fixed-five list and missing eligible enemy channels', () => {
  const fixed = fresh();
  fixed.encounters.find(row => row.id === 'gremlin_gang').enemies = [
    'mad_gremlin', 'sneaky_gremlin', 'fat_gremlin', 'wizard_gremlin', 'shield_gremlin',
  ];
  assert.ok(validateLaunchContent(fixed, { runtime: false }).some(error => error.includes('encounters/gremlin_gang/enemies')));
  for (const id of ['mad_gremlin', 'sneaky_gremlin', 'fat_gremlin', 'wizard_gremlin', 'shield_gremlin']) {
    const manifest = fresh();
    manifest.enemies.find(row => row.id === id).channels = ['encounter:cultist_solo'];
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes(`enemies/${id} channels`)));
  }
});
