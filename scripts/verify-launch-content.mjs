import assert from 'node:assert/strict';
import { readFileSync, existsSync, mkdtempSync, writeFileSync, rmSync, readdirSync } from 'node:fs';
import { resolve, join, dirname, basename } from 'node:path';
import { createHash } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { loadContent } from './validate-data.mjs';
import { luaString, toLua } from './build-lua-data.mjs';
import { runLua } from './test-lua.mjs';
import { candidateScriptFiles } from './native-candidate-scripts.mjs';

const categories = ['cards', 'sharedCards', 'generatedCards', 'enemies', 'encounters', 'events', 'relics', 'potions', 'bosses'];
const ids = rows => rows.map(row => row.id).sort();
const curseEvents = {
  regret: ['event:golden_shrine:desecrate', 'explicit_event:big_fish:box'],
  doubt: ['explicit_event:sssserpent:confirm'], pain: ['explicit_event:accursed_blacksmith:rummage'],
  decay: ['explicit_event:wheel:accept'],
    injury: ['explicit_event:golden_idol:injury'],
    parasite: ['explicit_event:mushrooms:heal'],
};
const specialRelicEvents = {
  mark_of_bloom: ['explicit_event:mind_bloom:upgrade'],
  neows_lament: ['explicit:Nodes.beginNeow:THREE_ENEMY_KILL'],
  red_mask: ['explicit_event:tomb_red_mask:pay'],
  warped_tongs: ['explicit_event:accursed_blacksmith:rummage'],
    spirit_poop: ['explicit_event:bonfire:curse_offer'], circlet: ['explicit_event:bonfire:repeat_curse_offer', 'explicit_event:golden_idol:repeat_take', 'explicit_event:mushrooms:repeat_fight'],
    golden_idol: ['explicit_event:golden_idol:take'],
    odd_mushroom: ['explicit_event:mushrooms:fight'],
};
const json = path => JSON.parse(readFileSync(path, 'utf8'));
const runtimeModules = Object.entries({
  abyss_nodes: ['abyss_run'],
  abyss_run: ['abyss_run_initialization', 'abyss_run_transition', 'abyss_run_rooms', 'abyss_run_settlement', 'abyss_run_potions'],
  abyss_run_initialization: ['abyss_encounter_queue'], abyss_run_transition: ['abyss_encounter_queue'],
  abyss_run_rooms: ['abyss_encounter_queue', 'abyss_room_encounters'],
  abyss_run_settlement: ['abyss_combat'], abyss_run_potions: ['abyss_combat'],
  abyss_room_encounters: ['abyss_encounter_formation'], abyss_combat: ['abyss_encounter_formation'],
  abyss_encounter_formation: ['abyss_sts_random'], abyss_encounter_queue: ['abyss_sts_random'],
}).map(([name, requires]) => ({ name, source: `src/lua/${name}.lua`, requires }));
const runtimeCache = new Map();

// The inventory remains an independent contract. Both the actual Lua requires
// and the real candidate packager's discovered modules must satisfy every edge.
export function validateLaunchRuntimeModules(modules, { sources, deployment, entryPoints }) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  check(isDeepStrictEqual(modules, runtimeModules), 'runtime deployment relationships: inventory differs from production');
  for (const module of runtimeModules) {
    check(deployment.includes(module.name), `runtime deployment missing module ${module.name}`);
    const source = sources[module.source];
    check(typeof source === 'string', `runtime source missing ${module.source}`);
    const requires = [...(source ?? '').matchAll(/require\s*\(\s*["']([^"']+)["']\s*\)/g)].map(match => match[1]);
    for (const name of module.requires) {
      check(requires.includes(name), `runtime dependency missing ${module.name} -> ${name}`);
      check(deployment.includes(name), `runtime deployment missing dependency ${name}`);
    }
    check(entryPoints.includes(module.source), `encounters profile missing deployed entry ${module.source}`);
  }
  return errors;
}

export function inspectLaunchRuntime(root = process.cwd(), data = loadContent(resolve(root, 'data'))) {
  const sourceDirectory = resolve(root, 'src/lua');
  const probe = resolve(root, 'tests/fixtures/launch-content/runtime-inventory.lua');
  const fingerprint = createHash('sha256').update(JSON.stringify(data)).update(readFileSync(probe));
  for (const file of readdirSync(sourceDirectory).filter(file => file.endsWith('.lua')).sort())
    fingerprint.update(file).update(readFileSync(join(sourceDirectory, file)));
  const key = `${resolve(root)}:${fingerprint.digest('hex')}`;
  if (runtimeCache.has(key)) return runtimeCache.get(key);
  const directory = mkdtempSync(join(tmpdir(), 'abyss-launch-runtime-'));
  try {
    // Inspect the actual packager's source-module discovery without building a
    // candidate. Its generated-file preflight only needs isolated metadata
    // placeholders; none of these values are executed or deployed.
    for (const name of ['abyss_art_features', 'abyss_data', 'abyss_original_v4_data', 'abyss_map_layout', 'abyss_narrative', 'abyss_presentation', 'abyss_theme', 'abyss_menu_background_asset', 'abyss_ready_card_binding', 'abyss_ready_card_assets', 'abyss_traveler_portrait_assets'])
      writeFileSync(join(directory, `${name}.lua`), '-- deployment metadata inspection only\n');
    const deployment = candidateScriptFiles(sourceDirectory, directory).map(row => row.name);
    const script = join(directory, 'inspect.lua');
    writeFileSync(script, `LAUNCH_DATA=${toLua(data)}\ndofile(${luaString(probe)})\n`);
    const result = runLua(script, { cwd: root });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /LAUNCH_RUNTIME_ENTRY_PASS/);
    const bindings = result.stdout.split(/\r?\n/).filter(line => line.startsWith('LAUNCH_RUNTIME\t'))
      .map(line => JSON.parse(line.slice('LAUNCH_RUNTIME\t'.length)));
    const events = result.stdout.split(/\r?\n/).filter(line => line.startsWith('LAUNCH_EVENT\t'))
      .map(line => JSON.parse(line.slice('LAUNCH_EVENT\t'.length)));
    const records = prefix => result.stdout.split(/\r?\n/).filter(line=>line.startsWith(prefix))
      .map(line=>JSON.parse(line.slice(prefix.length)));
    const snapshot = { bindings, deployment, events,
      sharedCards: records('LAUNCH_SHARED_CARD\t'),potions:records('LAUNCH_POTION\t') };
    runtimeCache.set(key, snapshot);
    return snapshot;
  } finally {
    assert.equal(dirname(directory), resolve(tmpdir()));
    assert.ok(basename(directory).startsWith('abyss-launch-runtime-'));
    rmSync(directory, { recursive: true, force: true });
  }
}

// Independent declarative inventory of the formation rule. The real Lua
// assembler is evaluated separately; identical decision paths must return the
// same ordered members, including repeated pool slots and discarded candidates.
function formationTraces(formation) {
  const traces = [];
  const visit = prefix => {
    let cursor = 0;
    const path = [];
    const pick = (kind, lo, hi) => {
      assert.ok(hi >= lo && hi - lo < 8, 'invalid formation decision range');
      if (cursor === prefix.length) throw { decision: true, kind, lo, hi };
      const value = prefix[cursor++]; path.push(`${kind}:${lo}:${hi}:${value}`); return value;
    };
    const candidate = value => {
      if (typeof value === 'string') return value;
      if (value.boolean) { assert.equal(value.boolean.length, 2); return value.boolean[pick('B', 0, 1)]; }
      assert.ok(value.candidates?.length > 0 && value.candidates.length <= 8, 'invalid candidate slot');
      const choices = value.candidates.map(candidate); // eager construction
      return choices[pick('I', 0, choices.length - 1)];
    };
    try {
      let members;
      if (formation.kind === 'fixed') members = formation.members;
      else if (formation.kind === 'boolean') members = pick('B', 0, 1) ? formation.onTrue : formation.onFalse;
      else if (formation.kind === 'slots') members = formation.slots.map(candidate);
      else {
        assert.equal(formation.kind, 'without-replacement');
        const pool = [...formation.pool];
        assert.ok(Number.isInteger(formation.count) && formation.count > 0 && formation.count <= pool.length && pool.length <= 8);
        members = Array.from({ length: formation.count }, () => pool.splice(pick('I', 0, pool.length - 1), 1)[0]);
      }
      assert.ok(Array.isArray(members) && members.length > 0 && members.every(id => typeof id === 'string'));
      assert.ok(traces.length < 100000, 'formation inventory exceeds finite budget');
      traces.push({ path: path.join('/'), members });
    } catch (error) {
      if (!error.decision) throw error;
      for (let value = error.lo; value <= error.hi; value++) visit([...prefix, value]);
    }
  };
  visit([]); return traces;
}
const sortedTraces = traces => [...traces].sort((a, b) => a.path.localeCompare(b.path));
const membersOf = binding => [...new Set(binding.traces.flatMap(trace => trace.members))].sort();

// This gate checks the inventory against production data and support predicates.
// It deliberately grants no platform/live acceptance and never rewrites the pool.
export function validateLaunchContent(manifest, { root = process.cwd(), runtime = true } = {}) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  const same = (actual, expected, label) => {
    if (!isDeepStrictEqual(actual, expected)) errors.push(`${label}: inventory differs from production`);
  };
  check(manifest.schemaVersion === 2, 'Unsupported launch inventory schema');
  check(manifest.status === 'scope-baseline-awaiting-per-item-acceptance', 'Inventory must not imply completed M3 acceptance');
  const data = loadContent(resolve(root, 'data'));
  for (const category of [...categories, 'legacyData.encounters']) {
    const rows = category === 'legacyData.encounters' ? manifest.legacyData?.encounters : manifest[category];
    check(Array.isArray(rows) && rows.length > 0, `${category}: missing entries`);
    if (!Array.isArray(rows)) continue;
    check(new Set(ids(rows)).size === rows.length, `${category}: duplicate ID`);
    for (const row of rows) {
      const label = `${category}/${row.id}`;
      check(typeof row.id === 'string' && row.id.length > 0, `${label}: missing ID`);
      check(Array.isArray(row.channels) && row.channels.length > 0, `${label}: no legal channel`);
      check(typeof row.source === 'string' && existsSync(resolve(root, row.source.split('#')[0])), `${label}: missing source`);
      const profile = manifest.profiles?.[row.profile];
      check(Boolean(profile), `${label}: missing verification profile`);
      if (!profile) continue;
      check(profile.tasks?.includes('TASK-47'), `${label}: missing content acceptance owner`);
      check(profile.entryPoints?.length > 0, `${label}: missing production entry point`);
      for (const file of [...(profile.entryPoints ?? []), ...(profile.local?.testFiles ?? [])]) {
        check(existsSync(resolve(root, file)), `${label}: missing evidence/entry file ${file}`);
      }
      check(profile.local?.status === 'coverage-recorded', `${label}: local coverage must not imply natural gameplay acceptance`);
      for (const layer of ['platform', 'live']) {
        check(profile[layer]?.status?.startsWith('pending-') && profile[layer]?.evidence?.length === 0,
          `${label}: ${layer} acceptance requires a separate per-item evidence schema and review`);
      }
    }
  }
  if (errors.length) return errors;
  const listedCards = [...manifest.cards, ...manifest.generatedCards, ...manifest.exclusions.cards];
  same(ids(listedCards), ids(data.cards.cards), 'cards including explicit exclusions');
  check(manifest.cards.length === 75, 'Frozen launch scope requires exactly 75 class cards');
  for (const card of manifest.cards) {
    const definition = data.cards.cards.find(row => row.id === card.id);
    same(card.versions, ['base', 'upgraded'], `cards/${card.id} versions`);
    check(Boolean(definition?.upgrade), `cards/${card.id}: missing upgraded definition`);
    check(card.rarity === definition?.rarity, `cards/${card.id}: rarity drift`);
    const channels = definition?.rarity === 'basic'
      ? ['starter_deck', 'camp_upgrade', 'event_upgrade']
      : ['combat_card_reward', 'shop_colored_card', 'camp_upgrade', 'event_upgrade'];
    same(card.channels, channels, `cards/${card.id} channels`);
    check(card.bossReward === (definition?.rarity === 'rare'), `cards/${card.id}: Boss reward rarity drift`);
  }
  same(ids(manifest.generatedCards), ids(data.cards.cards.filter(row => ['status', 'curse'].includes(row.type))), 'generated status/curse cards');
  for (const card of manifest.generatedCards) {
    const definition = data.cards.cards.find(row => row.id === card.id);
    check(card.type === definition?.type && card.countsTowardSeventyFive === false, `generatedCards/${card.id}: classification drift`);
    const bellCurse = card.id === 'curse_of_the_bell';
    const channels = bellCurse ? ['relic:calling_bell', 'explicit:Run.obtainCard']
      : card.type === 'curse' ? [...(curseEvents[card.id] ?? []),
      'explicit_event:transmogrifier:change', 'explicit_event:living_wall:change', 'explicit:Run.obtainCard']
      : [...data.enemies.enemies.filter(enemy => enemy.intents.some(intent => intent.effects.some(effect => effect.card === card.id)))
        .map(enemy => `enemy:${enemy.id}:intent`),
        ...data.cards.cards.filter(c => [c.effects,c.upgrade?.effects ?? []].some(list=>list.some(e=>e.card===card.id)))
          .map(c=>`card:${c.id}:effect`)];
    same(card.channels, channels, `generatedCards/${card.id} channels`);
    if (bellCurse) {
      check(card.sourceId === 'CurseOfTheBell' && definition?.sourceId === card.sourceId,
        'generatedCards/curse_of_the_bell: source ID drift');
      check(card.unremovable === true, 'generatedCards/curse_of_the_bell: unremovable boundary omitted');
    }
    if (card.type === 'curse') {
      check(!card.acquisitionPending, `generatedCards/${card.id}: explicit transformation route omitted`);
      check(Boolean(card.naturalAcquisitionLimitation?.includes(bellCurse ? 'Calling Bell' : 'explicit event')), `generatedCards/${card.id}: missing explicit acquisition boundary`);
    }
  }
  same(ids(manifest.enemies), ids(data.enemies.enemies), 'enemy definitions');
  check(manifest.legacyData?.role === 'explicit-id-development-replay-not-formal-source-pool', 'legacyData must not claim formal admission');
  same(ids(manifest.legacyData.encounters), ids(data.enemies.encounters), 'legacyData.encounters');
  for (const encounter of manifest.legacyData.encounters) {
    const definition = data.enemies.encounters.find(row => row.id === encounter.id);
    for (const field of ['tier', 'minFloor', 'maxFloor', 'enemies', 'enemiesOnTrue', 'gremlinPool', 'gremlinCount', 'lousePool', 'louseCount']) same(encounter[field], definition?.[field], `legacyData.encounters/${encounter.id}/${field}`);
    same(encounter.channels, ['explicit:Run.startCombat'], `legacyData.encounters/${encounter.id} channels`);
  }
  let actualRuntime;
  try { actualRuntime = inspectLaunchRuntime(root, data); }
  catch (error) { errors.push(`Formal runtime inspection failed: ${error.message}`); return errors; }
  same(ids(manifest.sharedCards),ids(actualRuntime.sharedCards),'sharedCards runtime identities');
  const sharedReference=json(resolve(root,'data/reference/sts1-card-pools/registration.json')).registration
    .filter(row=>row.sourcePath.startsWith('cards/colorless/'));
  const sharedSource=new Map(sharedReference.map(row=>[row.id,row]));
  for(const card of manifest.sharedCards){
    const actual=actualRuntime.sharedCards.find(row=>row.id===card.id);
    const reference=sharedSource.get(card.sourceId);
    check(Boolean(reference)&&actual?.sourceId===card.sourceId,`sharedCards/${card.id}: source ID drift`);
    same(card.versions,['base','upgraded'],`sharedCards/${card.id} versions`);
    check(card.rarity===actual?.rarity&&card.type===actual?.type&&card.rarity===reference?.rarity.toLowerCase(),`sharedCards/${card.id}: classification drift`);
    check(actual?.supported===true,`sharedCards/${card.id}: unsupported runtime effect`);
    same(card.channels,card.rarity==='special'?['explicit:Run.obtainCard',...(card.id==='apparition'?['explicit_event:ghosts:accept']:[]),...(card.id==='ritual_dagger'?['explicit_event:nest:dagger']:[])]:
      ['shop_colorless_card',...(reference?.tags.includes('HEALING')?[]:['shared_card_generation']),
        'explicit_event:sensory_stone:card_reward'],`sharedCards/${card.id} channels`);
    check(Boolean(card.naturalAcquisitionLimitation),`sharedCards/${card.id}: missing natural acceptance boundary`);
  }
  for (const [field, value] of Object.entries({ nodeEntry: 'abyss_nodes.enter', roomEntry: 'abyss_run.startRoomCombat', sourcePool: 'abyss_encounter_queue.rules' }))
    check(manifest.runtime?.[field] === value, `runtime deployment ${field} drift`);
  const sources = Object.fromEntries(runtimeModules.map(module => [module.source,
    existsSync(resolve(root, module.source)) ? readFileSync(resolve(root, module.source), 'utf8') : undefined]));
  errors.push(...validateLaunchRuntimeModules(manifest.runtime?.modules, {
    sources, deployment: actualRuntime.deployment, entryPoints: manifest.profiles.encounters.entryPoints,
  }));
  same(ids(manifest.encounters), actualRuntime.bindings.map(row => row.runtimeId).sort(), 'formal encounter source bindings');
  check(new Set(manifest.encounters.map(row => row.sourceName)).size === manifest.encounters.length, 'formal encounters duplicate source binding');
  for (const encounter of manifest.encounters) {
    const binding = actualRuntime.bindings.find(row => row.runtimeId === encounter.runtimeId);
    const label = `encounters/${encounter.id}`;
    check(encounter.id === encounter.runtimeId, `${label}: runtime ID drift`);
    check(Boolean(binding), `${label}: not a formal runtime binding`);
    if (!binding) continue;
    for (const field of ['sourceName', 'tier', 'queuePools']) same(encounter[field], binding[field], `${label}/${field}`);
    same(encounter.memberIds, membersOf(binding), `${label}/memberIds`);
    for (const id of membersOf(binding)) check(data.enemies.enemies.some(enemy => enemy.id === id && enemy.tier === binding.tier),
      `${label}: unregistered or wrong-tier runtime member ${id}`);
    const channels = binding.tier === 'normal' ? ['map:combat', 'unknown_room:monster']
      : binding.tier === 'elite' ? ['map:elite'] : ['map:boss:floor16'];
    same(encounter.channels, channels, `${label} channels`);
    check(!['minFloor', 'maxFloor', 'enemies', 'enemiesOnTrue', 'gremlinPool', 'gremlinCount', 'lousePool', 'louseCount'].some(field => Object.hasOwn(encounter, field)),
      `${label}: legacy fields cannot describe formal queue admission`);
    try { same(sortedTraces(formationTraces(encounter.formation)), sortedTraces(binding.traces), `${label}/formation`); }
    catch (error) { errors.push(`${label}/formation: invalid rule ${error.message}`); }
  }
  for (const enemy of manifest.enemies) {
    const definition = data.enemies.enemies.find(row => row.id === enemy.id);
    check(enemy.tier === definition?.tier, `enemies/${enemy.id}: tier drift`);
    check(existsSync(resolve(root, enemy.aiEntry)), `enemies/${enemy.id}: AI entry missing`);
    same(enemy.channels, actualRuntime.bindings.filter(row => membersOf(row).includes(enemy.id))
      .map(row => `encounter:${row.runtimeId}`).sort(), `enemies/${enemy.id} channels`);
  }
  same(ids(manifest.relics), ids(data.relics.relics), 'relic definitions');
  same(ids([...manifest.potions, ...manifest.exclusions.potions]), ids(data.potions.potions), 'potions including class exclusions');
  same(ids(manifest.potions), ids(actualRuntime.potions), 'obtainable potion predicates');
  same(ids(manifest.exclusions.potions.filter(row => row.acquisitionPending)), ids(data.potions.potions.filter(row => row.acquisitionPending)), 'pending potion exclusions');
  for (const potion of manifest.potions) {
    const definition = data.potions.potions.find(row => row.id === potion.id);
    check(potion.rarity === definition?.rarity, `potions/${potion.id}: rarity drift`);
    same(potion.channels, ['combat_potion_reward', 'shop_potion'], `potions/${potion.id} channels`);
  }
  for (const relic of manifest.relics) {
    const definition = data.relics.relics.find(row => row.id === relic.id);
    check(relic.rarity === definition?.rarity, `relics/${relic.id}: rarity drift`);
    const channels = definition?.rarity === 'starter' ? ['starting_relic']
      : definition?.rarity === 'boss' ? ['boss_treasure:floor17']
      : definition?.rarity === 'shop' ? ['shop_relic']
      : definition?.rarity === 'special' ? specialRelicEvents[relic.id]
      : ['treasure', ...(['courier', 'smiling_mask'].includes(relic.id) ? [] : ['shop_relic'])];
    same(relic.channels, channels, `relics/${relic.id} channels`);
    if (definition?.sourceId) check(relic.sourceId === definition.sourceId, `relics/${relic.id}: source ID drift`);
    if (definition?.rarity === 'special') check(Boolean(relic.naturalAcquisitionLimitation), `relics/${relic.id}: missing explicit-only boundary`);
    if (relic.id === 'spirit_poop') check(Boolean(relic.naturalExecutionLimitation?.includes('total-score')), 'relics/spirit_poop: unwired total-score boundary omitted');
    if (definition?.rarity === 'boss') check(Boolean(relic.naturalExecutionLimitation), `relics/${relic.id}: final-floor effect boundary omitted`);
  }
  same(ids(manifest.bosses), ids(data.enemies.enemies.filter(row => row.tier === 'boss')), 'Boss definitions');
  check(manifest.bosses.length === 1, 'Frozen launch scope requires exactly one Boss');
  for (const boss of manifest.bosses) {
    const binding = actualRuntime.bindings.find(row => row.tier === 'boss' && membersOf(row).includes(boss.id));
    check(boss.encounterId === binding?.runtimeId, `bosses/${boss.id}: formal Boss binding drift`);
    same(boss.channels, ['map:boss:floor16'], `bosses/${boss.id} channels`);
    check(boss.rewardDestination === 'boss_treasure:floor17', `bosses/${boss.id}: reward destination drift`);
  }
  check(data.rules.events.poolMode === 'restricted-seven', 'Production event mode changed: review launch scope');
  const explicitEvents = Object.fromEntries(actualRuntime.events.filter(row=>!row.random).map(row=>[row.id,row.originalId]));
  const eventIdentity = rows => rows.map(row=>`${row.originalId}:${row.id}`).sort();
  same(eventIdentity(manifest.events),eventIdentity(actualRuntime.events),'production event mappings');
  same(ids(manifest.events.filter(row => row.poolMode === 'explicit-only')), Object.keys(explicitEvents).sort(), 'explicit event routes');
  for (const event of manifest.events) {
    const explicit = Object.hasOwn(explicitEvents, event.id);
    if(event.id==='match_game')same(event.boardCommands,['flip','resolve','finish'],'events/match_game board commands');
    check(event.poolMode === (explicit ? 'explicit-only' : data.rules.events.poolMode), `events/${event.id}: pool mode drift`);
    same(event.channels, explicit ? ['explicit:Nodes.enter'] : ['unknown_room:event'], `events/${event.id} channels`);
    if (explicit) {
      check(event.originalId === explicitEvents[event.id], `events/${event.id}: source ID drift`);
      check(Boolean(event.naturalAcquisitionLimitation), `events/${event.id}: missing explicit-only boundary`);
      if (event.id === 'ghosts') {
        same(event.choices,['accept','leave'],'events/ghosts choices');
        same(event.stages,['intro','result'],'events/ghosts stages');
        check(event.source==='src/lua/abyss_ghosts_event.lua','events/ghosts source module');
        same(event.healthCost,{kind:'max_hp_loss',cachedAt:'room_entry',formula:'ceil(float32(float32(maxHp)*0.5)), capped at maxHp-1',
          appliedTo:'current_max_hp',minimumMaxHp:1,order:'before_permanent_obtains'},'events/ghosts cached health cost');
        same(event.permanentRewards,{cardId:'apparition',sourceId:'Ghostly',count:5,through:'Run.obtainCard'},'events/ghosts permanent rewards');
        for (const boundary of ['Native-client acceptance NOT_RUN','Toxic Egg','result then separate Leave'])
          check(event.naturalAcquisitionLimitation?.includes(boundary),`events/ghosts: missing ${boundary} boundary`);
      }
    }
  }
  for (const category of ['cards', 'potions', 'events']) for (const row of manifest.exclusions[category]) {
    check(!manifest[category].some(item => item.id === row.id), `${category}/${row.id}: excluded content admitted`);
    check(Boolean(row.reason), `${category}/${row.id}: missing exclusion reason`);
    if (row.path) check(existsSync(resolve(root, row.path)), `${category}/${row.id}: missing candidate path`);
  }
  if (runtime && errors.length === 0) {
    const directory = mkdtempSync(join(tmpdir(), 'abyss-launch-inventory-'));
    try {
      const script = join(directory, 'verify.lua');
      for (const phase of ['inventory', 'black_star', 'lizard_tail_run', 'lizard_tail_persistence']) {
        writeFileSync(script, `LAUNCH_DATA=${toLua(data)}\nLAUNCH_MANIFEST=${toLua(manifest)}\nLAUNCH_RUNTIME_PHASE=${luaString(phase)}\ndofile(${luaString(resolve(root, 'scripts/verify-launch-content.lua'))})\n`);
        const result = runLua(script, { cwd: root });
        if (result.status !== 0) errors.push(`Production Lua inventory gate failed (${phase}): ${result.stderr || result.stdout}`);
      }
    } finally { rmSync(directory, { recursive: true, force: true }); }
  }
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const manifest = json(process.argv[2] ?? 'data/release/launch-content.json');
    const errors = validateLaunchContent(manifest);
    if (errors.length) throw new Error(errors.join('\n'));
    console.log(`Launch inventory matches formal runtime: ${manifest.cards.length} class cards, ${manifest.generatedCards.length} status/curse definitions, ${manifest.enemies.length} enemies, ${manifest.encounters.length} source bindings (17 queue sources + Guardian), ${manifest.legacyData.encounters.length} separately retained legacy explicit-ID entries, ${manifest.events.filter(row => row.poolMode !== 'explicit-only').length} default-pool events + ${manifest.events.filter(row => row.poolMode === 'explicit-only').length} explicit-only routes, ${manifest.relics.length} relic definitions, ${manifest.potions.length} obtainable potions + ${manifest.exclusions.potions.filter(row => row.acquisitionPending).length} acquisition-pending effects, ${manifest.bosses.length} Boss. Recorded acquisition/effect gaps and per-item platform/live acceptance remain pending.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
