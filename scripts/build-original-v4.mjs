import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const ORIGINAL_V4_HASHES = Object.freeze({
  'cards_v4.json': '89229cdd7f6c1640d47bca95338f5e7887fbfd8720af181f7561d6eb45a45fca',
  'rules_v4.json': 'a100f8b0fd61e3724f0eda5e077055f82bcacb7a4536d337096d9a6389419c8e',
});
const VERSION = 'original_v4.0_frozen_2026-10-26';
const ROLES = ['HT', 'AR', 'FR', 'RD'];
const CATEGORIES = ['normal', 'charged', 'defense', 'skill', 'command', 'burst'];
const REQUIREMENTS = ['bond1', 'bond2', 'fan2', 'fan3', 'fan4', 'resolve2', 'resolve3'];
const CONDITIONS = new Set(['bloom_target', 'bond0', 'bond1', 'bond2', 'bond4', 'directive_target',
  'enemy_low', 'eye', 'fan0', 'fan2', 'fan3', 'fan4', 'fan6', 'has_bloom', 'has_directive',
  'has_guest', 'has_mature', 'has_singer', 'infused', 'low', 'mature_target', 'musou',
  'not_bond4', 'not_fan4', 'not_low', 'not_musou', 'ousia', 'pneuma',
  'resolve0', 'resolve2', 'resolve3', 'resolve4']);
const EFFECT_FIELDS = Object.freeze({
  absorb: ['target'], block: ['n'], block_spent: ['n', 'coefficient'], bloom: ['n', 'target'],
  bonus: ['n', 'tag'], cash_bloom: ['target?'], cleanse: [], counter: ['n'],
  damage: ['n', 'hits', 'target'], damage_spent: ['n', 'coefficient', 'target'],
  directive: ['target'], draw: ['n'], end_infuse: [], eye: ['n'], eye_pulse: [],
  heal: ['n'], heal_spent: ['n', 'coefficient'], infuse: ['n'], mature: ['target'],
  mode: ['mode'], musou: ['n'], next_block: ['n'], next_draw: ['n'], next_energy: ['n'],
  pay_hp: ['n'], resolve: ['n'], revelry: ['n'], singer: ['n'], soften: ['n'],
  spend: ['n', 'resource'], summon: ['n', 'member'], toggle: [], trigger: ['member'],
  when: ['condition', 'effects'],
});
function requireValue(value, message) {
  if (!value) throw new Error(message);
}
function record(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function inputPath(directory, file) {
  // Do not normalize away a symlink followed by .. before the OS traverses it.
  return `${directory}/${file}`;
}
function validateEffects(effects, where, nested = false) {
  requireValue(Array.isArray(effects) && effects.length > 0, `${where}: effects must be a nonempty array`);
  for (const effect of effects) {
    requireValue(record(effect) && Object.hasOwn(EFFECT_FIELDS, effect.op), `${where}: unknown op ${effect?.op}`);
    const fields = EFFECT_FIELDS[effect.op];
    const allowed = new Set(['op', ...fields.map(field => field.replace(/\?$/, ''))]);
    requireValue(Object.keys(effect).every(key => allowed.has(key)), `${where}: unsupported ${effect.op} field`);
    for (const field of fields.filter(field => !field.endsWith('?'))) {
      requireValue(Object.hasOwn(effect, field), `${where}: missing ${effect.op}.${field}`);
    }
    if (Object.hasOwn(effect, 'n')) requireValue(
      (effect.op === 'spend' && effect.n === 'all') || (Number.isSafeInteger(effect.n) && effect.n >= 0),
      `${where}: invalid ${effect.op}.n`);
    if (Object.hasOwn(effect, 'coefficient')) requireValue(
      Number.isFinite(effect.coefficient) && effect.coefficient >= 0, `${where}: invalid coefficient`);
    if (Object.hasOwn(effect, 'hits')) requireValue(Number.isSafeInteger(effect.hits) && effect.hits > 0, `${where}: invalid hits`);
    if (Object.hasOwn(effect, 'target')) requireValue(['one', 'all'].includes(effect.target), `${where}: unknown target`);
    if (Object.hasOwn(effect, 'tag')) requireValue(['normal', 'charged', 'any'].includes(effect.tag), `${where}: unknown bonus tag`);
    if (Object.hasOwn(effect, 'mode')) requireValue(['ousia', 'pneuma'].includes(effect.mode), `${where}: unknown mode`);
    if (Object.hasOwn(effect, 'resource')) requireValue(['bond', 'fan', 'resolve'].includes(effect.resource), `${where}: unknown resource`);
    if (Object.hasOwn(effect, 'member')) requireValue(
      (effect.op === 'summon' ? ['usher', 'chevalmarin', 'crabaletta'] : ['usher', 'chevalmarin', 'crabaletta', 'singer', 'all']).includes(effect.member),
      `${where}: unknown member`);
    requireValue(!nested || !['pay_hp', 'spend'].includes(effect.op), `${where}: conditional resource payment unsupported`);
    if (effect.op === 'when') {
      requireValue(CONDITIONS.has(effect.condition), `${where}: unknown condition ${effect.condition}`);
      validateEffects(effect.effects, where, true);
    }
  }
}
function validateData(cards, rules) {
  requireValue(cards.version === VERSION && rules.version === VERSION, 'Original V4 version mismatch');
  requireValue(Array.isArray(cards.cards) && cards.cards.length === 300, 'Original V4 requires 300 cards');
  const ids = new Set(), counts = Object.fromEntries(ROLES.map(role => [role, 0]));
  let definitions = 0;
  for (const card of cards.cards) {
    const match = typeof card.id === 'string' && /^(HT|AR|FR|RD)2-(\d{3})$/.exec(card.id);
    requireValue(match && card.role === match[1] && +match[2] >= 1 && +match[2] <= 75, `Invalid original V4 ID/role: ${card.id}`);
    requireValue(!ids.has(card.id), `Duplicate original V4 ID: ${card.id}`);
    ids.add(card.id); counts[card.role]++;
    requireValue(CATEGORIES.includes(card.category), `${card.id}: unknown category`);
    requireValue(['基础', '普通', '罕见', '稀有'].includes(card.rarity), `${card.id}: unknown rarity`);
    requireValue(Array.isArray(card.requirements) && card.requirements.every(condition => REQUIREMENTS.includes(condition)),
      `${card.id}: unknown or missing top-level requirements`);
    for (const version of ['base', 'upgrade']) {
      const definition = card[version], where = `${card.id}.${version}`;
      requireValue(record(definition) && Object.keys(definition).sort().join(',') === 'cost,effects,exhaust', `${where}: invalid definition fields`);
      requireValue(Number.isSafeInteger(definition.cost) && definition.cost >= 0 && typeof definition.exhaust === 'boolean', `${where}: invalid cost/exhaust`);
      validateEffects(definition.effects, where); definitions++;
    }
  }
  requireValue(definitions === 600 && ROLES.every(role => counts[role] === 75), 'Original V4 requires 75 cards and 150 definitions per role');
  for (const role of ROLES) {
    requireValue(record(rules.roles?.[role]) && rules.roles[role].starter?.length === 10
      && rules.roles[role].starter.every(id => ids.has(id) && id.startsWith(`${role}2-`)), `${role}: invalid starter deck`);
  }
}

export function loadOriginalV4(directory = 'data/original_v4') {
  const bytes = Object.fromEntries(Object.keys(ORIGINAL_V4_HASHES).map(file => [file, readFileSync(inputPath(directory, file))]));
  const cards = JSON.parse(bytes['cards_v4.json'].toString('utf8'));
  const rules = JSON.parse(bytes['rules_v4.json'].toString('utf8'));
  validateData(cards, rules);
  for (const [file, expected] of Object.entries(ORIGINAL_V4_HASHES)) {
    requireValue(createHash('sha256').update(bytes[file]).digest('hex') === expected, `Frozen original V4 hash mismatch: ${file}`);
  }
  return { version: cards.version, cards: cards.cards, rules };
}

export function originalV4ToLua(value) {
  if (value === null) return 'nil'; // JSON null is the absence of a Lua configuration value.
  if (typeof value === 'string') {
    requireValue(value.isWellFormed(), 'Lua strings require well-formed Unicode');
    return '"' + [...Buffer.from(value, 'utf8')].map(byte => byte >= 32 && byte <= 126 && byte !== 34 && byte !== 92
      ? String.fromCharCode(byte) : `\\${String(byte).padStart(3, '0')}`).join('') + '"';
  }
  if (typeof value === 'boolean') return String(value);
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  if (Array.isArray(value)) return `{${value.map(originalV4ToLua).join(',')}}`;
  if (record(value)) return `{${Object.keys(value).sort().map(key => `[${originalV4ToLua(key)}]=${originalV4ToLua(value[key])}`).join(',')}}`;
  throw new TypeError(`Unsupported Lua data value: ${String(value)}`);
}
function rejectInputOutputAlias(directory, output) {
  let destination;
  try { destination = { stat: statSync(output, { bigint: true }), path: realpathSync.native(output) }; }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  for (const file of Object.keys(ORIGINAL_V4_HASHES)) {
    const input = inputPath(directory, file), inputStat = statSync(input, { bigint: true });
    if (destination && (destination.path === realpathSync.native(input)
      || (destination.stat.dev === inputStat.dev && destination.stat.ino === inputStat.ino))) {
      throw new Error(`Output must not overwrite an input file: ${input}`);
    }
  }
}
export function buildOriginalV4(directory = 'data/original_v4', output = 'build/lua/abyss_original_v4_data.lua') {
  const data = loadOriginalV4(directory);
  rejectInputOutputAlias(directory, output);
  const source = `-- Generated from frozen Original V4 JSON. Do not edit.\nreturn ${originalV4ToLua(data)}\n`;
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, source, 'utf8');
  return source;
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.length > 4) throw new Error('Usage: node scripts/build-original-v4.mjs [data-directory] [output-file]');
    buildOriginalV4(process.argv[2], process.argv[3]);
    console.log('Frozen Original V4 Lua data module built (300 cards, 600 definitions).');
  } catch (error) { console.error(`Original V4 build failed: ${error.message}`); process.exitCode = 1; }
}
