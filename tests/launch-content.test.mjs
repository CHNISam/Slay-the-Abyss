import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLaunchContent } from '../scripts/verify-launch-content.mjs';

const fresh = () => JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));

test('launch inventory names every formal source binding rather than the legacy explicit-ID pool', () => {
  const manifest = fresh();
  const vectors = JSON.parse(readFileSync('tests/fixtures/sts1-encounter-runtime-vectors.json', 'utf8'));
  const sourceNames = [...new Set(vectors.cases.map(row => row.source))].sort();
  assert.deepEqual(manifest.encounters.map(row => row.sourceName).sort(), sourceNames);
  for (const id of ['large_slime', 'lots_of_slimes', 'exordium_thugs'])
    assert.ok(manifest.encounters.some(row => row.runtimeId === id), `formal runtime binding missing: ${id}`);
  for (const id of ['medium_slimes', 'large_acid', 'large_spike'])
    assert.ok(!manifest.encounters.some(row => row.runtimeId === id || row.id === id), `legacy fixture admitted: ${id}`);
});
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
  const encounter = fresh(); encounter.encounters[0].formation.members = ['guardian'];
  assert.ok(validateLaunchContent(encounter, { runtime: false }).some(error => error.includes('encounters/')));
  const relic = fresh(); delete relic.relics.find(row => row.id === 'sozu').naturalExecutionLimitation;
  assert.ok(validateLaunchContent(relic, { runtime: false }).some(error => error.includes('final-floor')));
});
test('actual production predicate rejects replacing a supported card with an unimplemented definition', () => {
  const manifest = fresh();
  manifest.cards.find(row => row.id === 'cleave').id = 'clash';
  manifest.exclusions.cards.find(row => row.id === 'clash').id = 'cleave';
  assert.ok(validateLaunchContent(manifest).some(error => error.includes('Playable card pool drift')));
});

test('inventory includes and validates the true branch of a dynamic encounter', () => {
  const manifest = fresh();
  const branch = manifest.legacyData.encounters.find(row => row.id === 'small_slimes');
  delete branch.enemiesOnTrue;
  assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes('enemiesOnTrue')));
  const missingChannel = fresh();
  missingChannel.enemies.find(row => row.id === 'acid_slime_m').channels = ['encounter:medium_slimes'];
  assert.ok(validateLaunchContent(missingChannel, { runtime: false }).some(error => error.includes('enemies/acid_slime_m channels')));
});

test('gremlin launch inventory accepts the four-of-eight production pool without fixed enemies', () => {
  const manifest = fresh();
  const gang = manifest.encounters.find(row => row.id === 'gremlin_gang');
  assert.equal(gang.formation.count, 4);
  assert.deepEqual(gang.formation.pool, [
    'mad_gremlin', 'mad_gremlin', 'sneaky_gremlin', 'sneaky_gremlin',
    'fat_gremlin', 'fat_gremlin', 'shield_gremlin', 'wizard_gremlin',
  ]);
  assert.equal(Object.hasOwn(gang, 'enemies'), false);
  assert.deepEqual(validateLaunchContent(manifest, { runtime: false }), []);
});

test('gremlin launch gate rejects missing, reordered, deduplicated, or wrong-count pool declarations', () => {
  for (const change of [
    row => { delete row.formation.pool; },
    row => { row.formation.pool = [...new Set(row.formation.pool)]; },
    row => { row.formation.pool = [...row.formation.pool].reverse(); },
    row => { delete row.formation.count; },
    row => { row.formation.count = 5; },
  ]) {
    const manifest = fresh();
    change(manifest.encounters.find(row => row.id === 'gremlin_gang'));
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes('encounters/gremlin_gang/formation')));
  }
});

test('gremlin launch gate rejects a stale fixed-five list and missing eligible enemy channels', () => {
  const fixed = fresh();
  fixed.encounters.find(row => row.id === 'gremlin_gang').enemies = [
    'mad_gremlin', 'sneaky_gremlin', 'fat_gremlin', 'wizard_gremlin', 'shield_gremlin',
  ];
  assert.ok(validateLaunchContent(fixed, { runtime: false }).some(error => error.includes('legacy fields')));
  for (const id of ['mad_gremlin', 'sneaky_gremlin', 'fat_gremlin', 'wizard_gremlin', 'shield_gremlin']) {
    const manifest = fresh();
    manifest.enemies.find(row => row.id === id).channels = ['encounter:cultist_solo'];
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes(`enemies/${id} channels`)));
  }
});

test('formal source gate rejects missing bindings, runtime ID drift and legacy rows promoted into the pool', () => {
  for (const change of [
    manifest => { manifest.encounters = manifest.encounters.filter(row => row.sourceName !== 'Exordium Thugs'); },
    manifest => { manifest.encounters.find(row => row.id === 'large_slime').runtimeId = 'large_acid'; },
    manifest => { manifest.encounters.push({ ...manifest.encounters[0], id: 'medium_slimes', runtimeId: 'medium_slimes', sourceName: 'Medium Slimes' }); },
    manifest => {
      const row = manifest.encounters.find(row => row.id === 'large_slime');
      manifest.encounters = manifest.encounters.filter(row => row !== row);
      for (const id of ['large_acid', 'large_spike']) manifest.encounters.push({ ...row, id, runtimeId: id });
    },
  ]) {
    const manifest = fresh(); change(manifest);
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => /formal|runtime ID|source binding/.test(error)));
  }
});

test('formal member and channel ranges include every selected Thugs and Wildlife candidate', () => {
  for (const id of ['exordium_thugs', 'wildlife']) {
    const manifest = fresh();
    const row = manifest.encounters.find(row => row.id === id);
    assert.ok(row.memberIds.includes('red_louse') && row.memberIds.includes('acid_slime_m'));
    row.memberIds = row.memberIds.filter(member => member !== 'red_louse');
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes(`encounters/${id}/memberIds`)));
    const missing = fresh();
    missing.enemies.find(enemy => enemy.id === 'acid_slime_m').channels = missing.enemies.find(enemy => enemy.id === 'acid_slime_m')
      .channels.filter(channel => channel !== `encounter:${id}`);
    assert.ok(validateLaunchContent(missing, { runtime: false }).some(error => error.includes('enemies/acid_slime_m channels')));
  }
  const channel = fresh(); channel.encounters.find(row => row.id === 'elite_nob').channels.push('unknown_room:monster');
  assert.ok(validateLaunchContent(channel, { runtime: false }).some(error => error.includes('encounters/elite_nob channels')));
});

test('legacy Data encounters retain exact branches, pool order and explicit-only channels', () => {
  for (const change of [
    row => { delete row.gremlinPool; }, row => { row.gremlinPool.reverse(); }, row => { row.gremlinCount = 5; },
    row => { row.channels = ['map:combat']; },
  ]) {
    const manifest = fresh(); change(manifest.legacyData.encounters.find(row => row.id === 'gremlin_gang'));
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes('legacyData.encounters/gremlin_gang')));
  }
});

test('runtime deployment requires the real source modules, dependencies and profile entry points', () => {
  for (const change of [
    manifest => { manifest.runtime.roomEntry = 'abyss_run.startCombat'; },
    manifest => { manifest.runtime.modules = manifest.runtime.modules.filter(row => row.name !== 'abyss_encounter_formation'); },
    manifest => { manifest.runtime.modules.find(row => row.name === 'abyss_run').requires = []; },
    manifest => { manifest.profiles.encounters.entryPoints = manifest.profiles.encounters.entryPoints.filter(file => !file.endsWith('abyss_room_encounters.lua')); },
  ]) {
    const manifest = fresh(); change(manifest);
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => /runtime deployment|deployed entry/.test(error)));
  }
});
