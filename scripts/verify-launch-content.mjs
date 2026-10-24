import assert from 'node:assert/strict';
import { readFileSync, existsSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { loadContent } from './validate-data.mjs';
import { luaString, toLua } from './build-lua-data.mjs';
import { runLua } from './test-lua.mjs';

const categories = ['cards', 'generatedCards', 'enemies', 'encounters', 'events', 'relics', 'potions', 'bosses'];
const ids = rows => rows.map(row => row.id).sort();
const json = path => JSON.parse(readFileSync(path, 'utf8'));

// This gate checks the inventory against production data and support predicates.
// It deliberately grants no platform/live acceptance and never rewrites the pool.
export function validateLaunchContent(manifest, { root = process.cwd(), runtime = true } = {}) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  const same = (actual, expected, label) => {
    try { assert.deepEqual(actual, expected); } catch { errors.push(`${label}: inventory differs from production`); }
  };
  check(manifest.schemaVersion === 1, 'Unsupported launch inventory schema');
  check(manifest.status === 'scope-baseline-awaiting-per-item-acceptance', 'Inventory must not imply completed M3 acceptance');
  const data = loadContent(resolve(root, 'data'));
  for (const category of categories) {
    const rows = manifest[category];
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
  check(manifest.cards.length === 30, 'Frozen launch scope requires exactly 30 class cards');
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
    check(card.type === definition?.type && card.countsTowardThirty === false, `generatedCards/${card.id}: classification drift`);
    const channels = card.type === 'curse' ? ['event:golden_shrine:desecrate']
      : data.enemies.enemies.filter(enemy => enemy.intents.some(intent => intent.effects.some(effect => effect.card === card.id)))
        .map(enemy => `enemy:${enemy.id}:intent`);
    same(card.channels, channels, `generatedCards/${card.id} channels`);
  }
  same(ids(manifest.enemies), ids(data.enemies.enemies), 'enemy definitions');
  same(ids(manifest.encounters), ids(data.enemies.encounters), 'encounters');
  for (const encounter of manifest.encounters) {
    const definition = data.enemies.encounters.find(row => row.id === encounter.id);
    for (const field of ['tier', 'minFloor', 'maxFloor', 'enemies', 'enemiesOnTrue']) same(encounter[field], definition?.[field], `encounters/${encounter.id}/${field}`);
  }
  for (const enemy of manifest.enemies) {
    const definition = data.enemies.enemies.find(row => row.id === enemy.id);
    check(enemy.tier === definition?.tier, `enemies/${enemy.id}: tier drift`);
    check(existsSync(resolve(root, enemy.aiEntry)), `enemies/${enemy.id}: AI entry missing`);
    same(enemy.channels, data.enemies.encounters.filter(row => row.enemies.includes(enemy.id)
      || row.enemiesOnTrue?.includes(enemy.id)).map(row => `encounter:${row.id}`), `enemies/${enemy.id} channels`);
  }
  same(ids(manifest.relics), ids(data.relics.relics), 'relic definitions');
  same(ids([...manifest.potions, ...manifest.exclusions.potions]), ids(data.potions.potions), 'potions including class exclusions');
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
      : ['treasure', ...(['courier', 'smiling_mask'].includes(relic.id) ? [] : ['shop_relic'])];
    same(relic.channels, channels, `relics/${relic.id} channels`);
    if (definition?.rarity === 'boss') check(Boolean(relic.naturalExecutionLimitation), `relics/${relic.id}: final-floor effect boundary omitted`);
  }
  same(ids(manifest.bosses), ids(data.enemies.enemies.filter(row => row.tier === 'boss')), 'Boss definitions');
  check(manifest.bosses.length === 1, 'Frozen launch scope requires exactly one Boss');
  check(data.rules.events.poolMode === 'restricted-seven', 'Production event mode changed: review launch scope');
  for (const event of manifest.events) check(event.poolMode === data.rules.events.poolMode, `events/${event.id}: pool mode drift`);
  for (const category of ['cards', 'potions', 'events']) for (const row of manifest.exclusions[category]) {
    check(!manifest[category].some(item => item.id === row.id), `${category}/${row.id}: excluded content admitted`);
    check(Boolean(row.reason), `${category}/${row.id}: missing exclusion reason`);
    if (row.path) check(existsSync(resolve(root, row.path)), `${category}/${row.id}: missing candidate path`);
  }
  if (runtime && errors.length === 0) {
    const directory = mkdtempSync(join(tmpdir(), 'abyss-launch-inventory-'));
    try {
      const script = join(directory, 'verify.lua');
      writeFileSync(script, `LAUNCH_DATA=${toLua(data)}\nLAUNCH_MANIFEST=${toLua(manifest)}\ndofile(${luaString(resolve(root, 'scripts/verify-launch-content.lua'))})\n`);
      const result = runLua(script, { cwd: root });
      if (result.status !== 0) errors.push(`Production Lua inventory gate failed: ${result.stderr || result.stdout}`);
    } finally { rmSync(directory, { recursive: true, force: true }); }
  }
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const manifest = json(process.argv[2] ?? 'data/release/launch-content.json');
    const errors = validateLaunchContent(manifest);
    if (errors.length) throw new Error(errors.join('\n'));
    console.log(`Launch inventory matches production: ${manifest.cards.length} class cards, ${manifest.enemies.length} enemies, ${manifest.encounters.length} encounters, ${manifest.events.length} events, ${manifest.relics.length} relics, ${manifest.potions.length} obtainable potions, ${manifest.bosses.length} Boss. Per-item platform/live acceptance remains pending.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
