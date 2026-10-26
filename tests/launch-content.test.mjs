import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLaunchContent, inspectLaunchRuntime } from '../scripts/verify-launch-content.mjs';

const fresh = () => JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));

test('shared cards cannot disappear from the inventory while remaining in the runtime',()=>{
  const missing=fresh();missing.sharedCards=[];
  assert.ok(validateLaunchContent(missing,{runtime:false}).some(error=>error.includes('sharedCards')));
});

test('every production event mapping is listed, including explicit transformation routes', () => {
  const actual=inspectLaunchRuntime();
  assert.ok(actual.events?.some(row=>row.id==='transmogrifier' && row.originalId==='Transmorgrifier'));
  assert.deepEqual(fresh().events.map(row=>row.id).sort(),actual.events.map(row=>row.id).sort());
  const omitted=fresh();omitted.events=omitted.events.filter(row=>row.id!=='transmogrifier');
  assert.ok(validateLaunchContent(omitted,{runtime:false}).some(error=>error.includes('production event mappings')));
});

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

test('expanded content records actual channels without granting natural acquisition', () => {
  const manifest = fresh();
  const definitions = name => JSON.parse(readFileSync(`data/${name}.json`, 'utf8'))[name];
  assert.deepEqual(manifest.relics.map(row => row.id).sort(), definitions('relics').map(row => row.id).sort());
  assert.equal(manifest.relics.filter(row => row.rarity === 'common').length, 33);
  assert.deepEqual(manifest.generatedCards.filter(row => row.type === 'curse').map(row => row.id).sort(),
    definitions('cards').filter(row => row.type === 'curse').map(row => row.id).sort());
  assert.equal(manifest.events.filter(row => row.poolMode === 'restricted-seven').length, 7);
  assert.equal(manifest.events.filter(row => row.poolMode === 'explicit-only').length, 16);
  assert.equal(manifest.sharedCards.length,39);
  assert.equal(manifest.potions.length, 33);
  assert.deepEqual(manifest.exclusions.potions.filter(row => row.acquisitionPending).map(row => row.id).sort(),
    definitions('potions').filter(row => row.acquisitionPending).map(row => row.id).sort());
});

test('gate rejects promoting explicit events, SPECIAL relics and pending potions into natural pools', () => {
  const event = fresh(); event.events.find(row => row.id === 'big_fish').channels = ['unknown_room:event'];
  assert.ok(validateLaunchContent(event, { runtime: false }).some(error => error.includes('events/big_fish channels')));
  for (const id of ['warped_tongs', 'spirit_poop', 'circlet', 'golden_idol']) {
    const manifest = fresh(); manifest.relics.find(row => row.id === id).channels = ['treasure', 'shop_relic'];
    assert.ok(validateLaunchContent(manifest, { runtime: false }).some(error => error.includes(`relics/${id} channels`)));
  }
  const potion = fresh(); potion.potions.push({...potion.potions[0],id:'poison_potion'});
  assert.ok(validateLaunchContent(potion, { runtime: false }).some(error => error.includes('obtainable potion predicates')));
  const curse = fresh(); delete curse.generatedCards.find(row => row.id === 'parasite').naturalAcquisitionLimitation;
  assert.ok(validateLaunchContent(curse, { runtime: false }).some(error => error.includes('generatedCards/parasite: missing explicit acquisition boundary')));
  const score = fresh(); delete score.relics.find(row => row.id === 'spirit_poop').naturalExecutionLimitation;
  assert.ok(validateLaunchContent(score, { runtime: false }).some(error => error.includes('unwired total-score boundary')));
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
test('production inventory rejects an unknown card in place of a required card', () => {
  const manifest = fresh();
  manifest.cards.find(row => row.id === 'cleave').id = 'unknown_card';
  assert.ok(validateLaunchContent(manifest).some(error => error.includes('cards')));
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
