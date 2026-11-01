import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync as readCurrentFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {validateLaunchContent as validateCurrentLaunchContent,inspectLaunchRuntime as inspectCurrentLaunchRuntime,validateLaunchRuntimeModules} from '../scripts/verify-launch-content.mjs';
import {launchBaselineFixture} from './helpers/launch-baseline-fixture.mjs';


const currentRoot = process.cwd();
const readFileSync = (path, encoding) => readCurrentFileSync(resolve(currentRoot, path), encoding);
const validateLaunchContent = (manifest, options = {}) =>
  validateCurrentLaunchContent(manifest, { ...options, root: currentRoot });
const inspectLaunchRuntime = () => inspectCurrentLaunchRuntime(currentRoot);

const fresh = () => JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));

test('legal current launch inventory is the positive control for all field mutations',()=>{
  assert.deepEqual(validateLaunchContent(fresh(),{runtime:false}),[]);
});

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
test('current inventory matches production data and actual Lua support pools', () => {
  assert.deepEqual(validateLaunchContent(fresh()), []);
});

test('expanded content records actual channels without granting natural acquisition', () => {
  const manifest = fresh();
  const definitions = name => JSON.parse(readFileSync(`data/${name}.json`, 'utf8'))[name];
  assert.deepEqual(manifest.relics.map(row => row.id).sort(), definitions('relics').map(row => row.id).sort());
  assert.equal(manifest.relics.filter(row => row.rarity === 'common').length, 36);
  assert.deepEqual(manifest.generatedCards.filter(row => row.type === 'curse').map(row => row.id).sort(),
    definitions('cards').filter(row => row.type === 'curse').map(row => row.id).sort());
  assert.equal(manifest.events.filter(row => row.poolMode === 'restricted-seven').length, 7);
  assert.deepEqual(manifest.events.filter(row=>row.poolMode==='explicit-only').map(row=>row.id).sort(),
    inspectLaunchRuntime().events.filter(row=>!row.random).map(row=>row.id).sort(),'every actual explicit-only production route is declared');
  for (const id of ['nest','mushrooms']) {
    const event=manifest.events.find(row=>row.id===id);
    assert.equal(event.poolMode,'explicit-only');assert.deepEqual(event.channels,['explicit:Nodes.enter']);
  }
  assert.equal(manifest.sharedCards.length,39);
  assert.equal(manifest.potions.length, 33);
  assert.deepEqual(manifest.exclusions.potions.filter(row => row.acquisitionPending).map(row => row.id).sort(),
    definitions('potions').filter(row => row.acquisitionPending).map(row => row.id).sort());
});

test('frozen formal launch retains its original thirty-one explicit event routes',()=>{
  const root=launchBaselineFixture();
  const original=JSON.parse(readCurrentFileSync(resolve(root,'data/release/launch-content.json'),'utf8'));
  assert.equal(original.events.filter(row=>row.poolMode==='explicit-only').length,31);
});

test('copy and Match production routes preserve separate candidate and pending platform acceptance',()=>{
  const manifest=fresh();
  for(const [id,originalId] of [['duplicator','Duplicator'],['match_game','Match and Keep!']]) {
    const event=manifest.events.find(row=>row.id===id);
    assert.equal(event.originalId,originalId);assert.equal(event.poolMode,'explicit-only');
    assert.deepEqual(event.channels,['explicit:Nodes.enter']);
    const profile=manifest.profiles[event.profile];
    assert.equal(profile.local.status,'coverage-recorded');
    assert.equal(profile.platform.status,'pending-per-item');assert.deepEqual(profile.platform.evidence,[]);
    assert.equal(profile.live.status,'pending-natural-acquisition-and-execution');assert.deepEqual(profile.live.evidence,[]);
    const missing=fresh();missing.events=missing.events.filter(row=>row.id!==id);
    assert.ok(validateLaunchContent(missing,{runtime:false}).some(error=>error.includes('production event mappings')));
  }
  assert.deepEqual(manifest.events.find(row=>row.id==='match_game').boardCommands,['flip','resolve','finish']);
  const wrongCommands=fresh();wrongCommands.events.find(row=>row.id==='match_game').boardCommands=['flip','finish'];
  assert.ok(validateLaunchContent(wrongCommands,{runtime:false}).some(error=>error.includes('board commands')));
  assert.ok(manifest.exclusions.events.some(row=>row.path==='tools/candidates/match_game.lua'));
});

test('Act3 event bridge evidence preserves pending native and natural acceptance', () => {
  const manifest = fresh();
  for (const [id, originalId] of [['mind_bloom', 'MindBloom'], ['mysterious_sphere', 'Mysterious Sphere']]) {
    const event = manifest.events.find(row => row.id === id);
    assert.equal(event.originalId, originalId);
    assert.equal(event.act, 3);
    assert.equal(event.poolMode, 'explicit-only');
    assert.deepEqual(event.channels, ['explicit:Nodes.enter']);
    const profile = manifest.profiles[event.profile];
    assert.ok(profile.local.testFiles.includes('tests/lua/event_combat_bridge.lua'));
    assert.equal(profile.platform.status, 'pending-per-item');
    assert.equal(profile.live.status, 'pending-natural-acquisition-and-execution');
    assert.deepEqual(profile.platform.evidence, []);
    assert.deepEqual(profile.live.evidence, []);
  }
});

test('current release requires only Geo two acts while future campaign evidence stays incomplete', () => {
  const manifest=fresh();
  assert.deepEqual(manifest.requiredScope.characters,['ironclad']);
  assert.deepEqual(manifest.requiredScope.acts,[1,2]);
  const campaign=JSON.parse(readFileSync('data/release/m3-campaign.json','utf8'));
  assert.deepEqual(campaign.currentReleaseScope.characters,['ironclad']);
  assert.deepEqual(campaign.currentReleaseScope.acts,[1,2]);
  assert.equal(campaign.currentReleaseScope.deferredCharacter,'raiden');
  assert.equal(campaign.acceptance,'INCOMPLETE');
});

test('campaign ledger distinguishes Act3/Act4 local components from natural, persistent and native acceptance', () => {
  const campaign = JSON.parse(readFileSync('data/release/m3-campaign.json', 'utf8'));
  assert.equal(campaign.acceptance, 'INCOMPLETE');
  assert.equal(campaign.core.hostChapterUI, 'IMPLEMENTED_FORMAL_CAMPAIGN_ENTRY_LOCAL');
  assert.match(readFileSync('src/lua/abyss_ui.lua','utf8'), /campaign = true/);
  assert.equal(campaign.core.persistentHistoricalUnlock, 'PLATFORM_UNVERIFIED');
  assert.equal(campaign.core.naturalKeyAcquisition, 'IMPLEMENTED_LOCAL_RUBY_RECALL_SAPPHIRE_TREASURE_EMERALD_REWARD_NATURAL_UNVERIFIED');
  assert.ok(campaign.core.keyAcquisitionEvidence.includes('tests/lua/emerald_key_run.lua'));
  assert.equal(campaign.core.sessionHistoricalUnlock, 'IMPLEMENTED_LOCAL_REAL_STANDARD_ACT3_VICTORIES_INJECTABLE_PROVIDER');
  const act3 = campaign.monsters.filter(row => row.act === 3);
  assert.equal(act3.length, 17);
  for (const row of act3) {
    assert.equal(row.implementation, 'IMPLEMENTED_LOCAL', row.className);
    assert.equal(row.localResult, 'RECORDED_LOCAL_COMPONENT_REGRESSION', row.className);
    assert.ok(row.evidence.length > 0, row.className);
    assert.equal(row.parityStatus, 'UNVERIFIED', row.className);
    assert.equal(row.platformStatus, 'NOT_RUN', row.className);
  }
  const act4Monsters = campaign.monsters.filter(row => row.act === 4);
  assert.deepEqual(act4Monsters.map(row => row.className).sort(), ['CorruptHeart', 'SpireShield', 'SpireSpear']);
  for (const row of act4Monsters) {
    assert.equal(row.implementation, 'IMPLEMENTED_LOCAL', row.className);
    assert.equal(row.localResult, 'RECORDED_LOCAL_COMPONENT_REGRESSION', row.className);
    assert.ok(row.evidence.includes('tests/lua/ending_enemy_runtime.lua'), row.className);
    assert.equal(row.parityStatus, 'UNVERIFIED', row.className);
    assert.equal(row.platformStatus, 'NOT_RUN', row.className);
  }
  const act4 = campaign.acts.find(row => row.act === 4);
  assert.equal(act4.combat, 'IMPLEMENTED_LOCAL_SHIELD_SPEAR_HEART_CONTROLLED_ROUTE');
  assert.equal(act4.events, 'NOT_APPLICABLE_FIXED_CAMP_SHOP_ELITE_BOSS_ROUTE');
  assert.ok(act4.evidence.includes('tests/lua/ending_route_characters.lua'));
  assert.match(act4.evidenceBoundary, /not natural acquisition/);
  assert.equal(campaign.platformStatus, 'NOT_RUN');
  assert.equal(campaign.officialImport, 'NOT_RUN');
  assert.deepEqual(campaign.naturalPlaythroughs, []);
  for (const act of campaign.acts) {
    assert.equal(act.normalPlaythrough, 'NOT_RUN');
    assert.equal(act.platform, 'NOT_RUN');
  }
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

test('three additional Act2 routes record only mocked-local UI wiring while native/natural/history/full-pool gates stay pending',()=>{
  const manifest=fresh();
  assert.match(manifest.profiles.events.limitation,/locally wired with mocked/);
  assert.match(manifest.profiles.events.limitation,/Actual native acceptance NOT_RUN/);
  for(const id of ['beggar','mausoleum','addict']){
    const row=manifest.events.find(event=>event.id===id);
    assert.deepEqual(row.channels,['explicit:Nodes.enter']);
    assert.equal(row.poolMode,'explicit-only');
    assert.match(row.naturalAcquisitionLimitation,/LOCAL_MOCKED_UI_WIRED/);
    assert.match(row.naturalAcquisitionLimitation,/Native-client acceptance NOT_RUN/);
    assert.match(row.naturalAcquisitionLimitation,/natural eligibility\/history/);
    assert.match(row.naturalAcquisitionLimitation,/history producer\/persistence/);
    assert.match(row.naturalAcquisitionLimitation,/complete relic pool acceptance/);
    assert.match(row.naturalAcquisitionLimitation,/empty mandatory purge group remains pending/);
  }
});

test('Back to Basics inventory keeps source-correct empty completion and V4 implementation boundary separate from native acceptance',()=>{
 const row=fresh().events.find(event=>event.id==='back_to_basics');
 assert.equal(row.originalId,'Back to Basics');assert.equal(row.poolMode,'explicit-only');
 assert.deepEqual(row.channels,['explicit:Nodes.enter']);assert.deepEqual(row.choices,['elegance','simplicity','purge','leave']);
 assert.match(row.naturalAcquisitionLimitation,/Empty Elegance and zero-upgrade Simplicity reach result then separate Leave/);
 assert.match(row.naturalAcquisitionLimitation,/V4 supports Elegance/);assert.match(row.naturalAcquisitionLimitation,/not a source class rule/);
 assert.match(row.naturalAcquisitionLimitation,/Native-client acceptance NOT_RUN/);
});

test('Ghosts launch ledger binds actual cached health cost and real five-card source acquisition without claiming natural completion',()=>{
 const manifest=fresh(),row=manifest.events.find(event=>event.id==='ghosts');
 assert.equal(row.originalId,'Ghosts');assert.equal(row.poolMode,'explicit-only');assert.deepEqual(row.channels,['explicit:Nodes.enter']);
 assert.deepEqual(row.choices,['accept','leave']);assert.deepEqual(row.stages,['intro','result']);
 assert.deepEqual(row.permanentRewards,{cardId:'apparition',sourceId:'Ghostly',count:5,through:'Run.obtainCard'});
 assert.match(row.naturalAcquisitionLimitation,/Native-client acceptance NOT_RUN/);assert.match(row.naturalAcquisitionLimitation,/Toxic Egg/);
 assert.deepEqual(manifest.sharedCards.find(card=>card.id==='apparition').channels,['explicit:Run.obtainCard','explicit_event:ghosts:accept']);
 for(const mutate of [m=>m.events.find(e=>e.id==='ghosts').permanentRewards.count=3,
   m=>m.events.find(e=>e.id==='ghosts').healthCost.cachedAt='accept',
   m=>m.events.find(e=>e.id==='ghosts').healthCost.order='after_permanent_obtains',
   m=>m.events.find(e=>e.id==='ghosts').naturalAcquisitionLimitation='all passed',
   m=>m.sharedCards.find(c=>c.id==='apparition').channels=['explicit:Run.obtainCard']]){
  const bad=fresh();mutate(bad);assert.ok(validateLaunchContent(bad,{runtime:false}).some(error=>/ghosts|apparition/.test(error)));
 }
});

// Exercise each extracted owner against real source text and the packager's
// actual discovered module set, then remove exactly one required fact at a time.
for (const helper of ['abyss_run_initialization', 'abyss_run_transition', 'abyss_run_rooms',
  'abyss_run_settlement', 'abyss_run_potions']) {
  test(`Run launch dependency gate rejects missing or disconnected ${helper}`, () => {
    const manifest = fresh(), modules = manifest.runtime.modules;
    const sources = Object.fromEntries(modules.map(row => [row.source, readFileSync(row.source, 'utf8')]));
    const context = { sources, deployment: inspectLaunchRuntime().deployment,
      entryPoints: manifest.profiles.encounters.entryPoints };
    const verify = (rows = modules, changes = {}) => validateLaunchRuntimeModules(rows, { ...context, ...changes });
    assert.deepEqual(verify(), []);
    const row = modules.find(row => row.name === helper);
    assert.ok(row, `helper is declared: ${helper}`);
    assert.ok(verify(modules.filter(row => row.name !== helper)).some(error => error.includes('runtime deployment relationships')));
    assert.ok(verify(modules, { deployment: context.deployment.filter(name => name !== helper) })
      .includes(`runtime deployment missing module ${helper}`));
    const missingSource = { ...sources }; delete missingSource[row.source];
    assert.ok(verify(modules, { sources: missingSource }).includes(`runtime source missing ${row.source}`));
    assert.ok(verify(modules, { entryPoints: context.entryPoints.filter(file => file !== row.source) })
      .includes(`encounters profile missing deployed entry ${row.source}`));
    const disconnected = structuredClone(modules);
    disconnected.find(module => module.name === 'abyss_run').requires =
      disconnected.find(module => module.name === 'abyss_run').requires.filter(name => name !== helper);
    assert.ok(verify(disconnected).some(error => error.includes('runtime deployment relationships')));
    for (const [owner, dependency] of [['abyss_run', helper], ...row.requires.map(name => [helper, name])]) {
      const file = `src/lua/${owner}.lua`;
      const removed = sources[file].replace(new RegExp(`require\\s*\\(\\s*["']${dependency}["']\\s*\\)`, 'g'), '{}');
      assert.notEqual(removed, sources[file], `mutated real dependency ${owner} -> ${dependency}`);
      assert.ok(verify(modules, { sources: { ...sources, [file]: removed } })
        .includes(`runtime dependency missing ${owner} -> ${dependency}`));
      const omitted = structuredClone(modules);
      omitted.find(module => module.name === owner).requires =
        omitted.find(module => module.name === owner).requires.filter(name => name !== dependency);
      assert.ok(verify(omitted).some(error => error.includes('runtime deployment relationships')));
    }
  });
}

test('formal deployment inventory includes generated art flags and all four art bindings without executing their data',()=>{
  const actual=inspectLaunchRuntime();
  for(const name of ['abyss_art_features','abyss_menu_background_asset','abyss_ready_card_binding','abyss_ready_card_assets','abyss_traveler_portrait_assets'])
    assert.equal(actual.deployment.filter(value=>value===name).length,1,name);
});
