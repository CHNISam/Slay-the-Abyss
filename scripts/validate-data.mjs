import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const contentFiles = ['cards', 'statuses', 'enemies', 'relics', 'potions'];
const tiers = ['normal', 'elite', 'boss'];
const valueOps = ['damage', 'damageAll', 'block', 'draw', 'energy', 'loseHp', 'heal',
  'blockPerTurn', 'discardRandom', 'increaseDamageThisCombat', 'gainTemporaryStrength',
  'exhaustRandom', 'exhaustChoose', 'putOnDrawPile'];
const statusOps = ['gainStatus', 'applyStatus', 'applyStatusAll', 'gainStatusPerTurn'];
const cardOps = ['addCardToDiscard', 'addCardPerTurn'];
const flagOps = ['damageEqualToBlock', 'doubleBlock', 'noDrawThisTurn', 'healEqualToDamageDealt'];
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);

/** Validate the complete content bundle; errors carry source paths for authoring. */
export function validateContent(bundle) {
  const errors = [];
  const fail = (path, message) => errors.push(`${path}: ${message}`);
  const object = (value, path) => isObject(value) || (fail(path, 'must be an object'), false);
  const text = (value, path) => typeof value === 'string' && value.trim().length > 0 ||
    (fail(path, 'must be a nonempty string'), false);
  const integer = (value, path, min = 0, max = Number.MAX_SAFE_INTEGER) =>
    Number.isSafeInteger(value) && value >= min && value <= max ||
    (fail(path, `must be an integer in ${min}..${max}`), false);
  const enumeration = (value, allowed, path) => allowed.includes(value) ||
    (fail(path, `must be one of ${allowed.join(', ')}`), false);
  const array = (value, path) => {
    if (!Array.isArray(value) || value.length === 0) { fail(path, 'must be a nonempty array'); return []; }
    return value;
  };
  if (!object(bundle, 'data')) return errors;
  const lists = {};
  for (const file of contentFiles) {
    lists[file] = object(bundle[file], `${file}.json`) ? array(bundle[file][file], `${file}.${file}`) : [];
  }
  lists.encounters = isObject(bundle.enemies) ? array(bundle.enemies.encounters, 'enemies.encounters') : [];
  const ids = {};
  for (const [kind, entries] of Object.entries(lists)) {
    ids[kind] = new Set();
    entries.forEach((entry, i) => {
      const path = `${kind}[${i}]`;
      if (!object(entry, path)) return;
      if (text(entry.id, `${path}.id`)) {
        if (!/^[a-z][a-z0-9_]*$/.test(entry.id)) fail(`${path}.id`, 'must use lowercase snake_case');
        if (ids[kind].has(entry.id)) fail(`${path}.id`, `duplicate ID ${entry.id}`);
        ids[kind].add(entry.id);
      }
      if (kind !== 'encounters') text(entry.name, `${path}.name`);
    });
  }
  const reference = (value, kind, path) => {
    if (text(value, path) && !ids[kind].has(value)) fail(path, `unknown ${kind} ID ${value}`);
  };
  function effects(value, path, depth = 0) {
    if (depth > 8) { fail(path, 'conditional nesting exceeds 8'); return; }
    array(value, path).forEach((effect, i) => {
      const p = `${path}[${i}]`;
      if (!object(effect, p)) return;
      const op = effect.op;
      if (!enumeration(op, [...valueOps, ...statusOps, ...cardOps, ...flagOps, 'conditional'], `${p}.op`)) return;
      if (valueOps.includes(op) || statusOps.includes(op) || op === 'addCardPerTurn') {
        const signed = statusOps.includes(op) && ['strength', 'dexterity'].includes(effect.status);
        integer(effect.value, `${p}.value`, signed ? Number.MIN_SAFE_INTEGER : 0);
      }
      if (statusOps.includes(op)) reference(effect.status, 'statuses', `${p}.status`);
      if (cardOps.includes(op)) reference(effect.card, 'cards', `${p}.card`);
      if (effect.times !== undefined) integer(effect.times, `${p}.times`, 1);
      if (effect.mayChoose !== undefined && typeof effect.mayChoose !== 'boolean') fail(`${p}.mayChoose`, 'must be boolean');
      if (op === 'conditional') {
        enumeration(effect.if, ['target_vulnerable'], `${p}.if`);
        effects(effect.then, `${p}.then`, depth + 1);
      }
    });
  }
  function card(card, path, partial = false) {
    if (!object(card, path)) return;
    if (!partial || card.type !== undefined) enumeration(card.type, ['attack', 'skill', 'power', 'status', 'curse'], `${path}.type`);
    if (!partial || card.rarity !== undefined) enumeration(card.rarity, ['basic', 'common', 'uncommon', 'rare', 'special'], `${path}.rarity`);
    if (!partial || card.cost !== undefined) integer(card.cost, `${path}.cost`, 0, 5);
    if (!partial || card.effects !== undefined) effects(card.effects, `${path}.effects`);
    if (card.condition !== undefined) enumeration(card.condition, ['only_attacks_in_hand'], `${path}.condition`);
    if (card.costMode !== undefined) enumeration(card.costMode, ['all_energy'], `${path}.costMode`);
    for (const flag of ['exhaust', 'ethereal', 'innate', 'repeatable']) {
      if (card[flag] !== undefined && typeof card[flag] !== 'boolean') fail(`${path}.${flag}`, 'must be boolean');
    }
    if (card.upgrade !== undefined && !partial) cardUpgrade(card.upgrade, `${path}.upgrade`);
  }
  function cardUpgrade(upgrade, path) {
    card(upgrade, path, true);
    if (isObject(upgrade) && Object.keys(upgrade).length === 0) fail(path, 'must change at least one field');
  }
  lists.cards.forEach((entry, i) => card(entry, `cards[${i}]`));
  const starter = bundle.cards?.starter_deck;
  if (object(starter, 'cards.starter_deck')) array(starter.cards, 'cards.starter_deck.cards').forEach((id, i) => reference(id, 'cards', `cards.starter_deck.cards[${i}]`));
  lists.statuses.forEach((entry, i) => {
    if (!isObject(entry)) return;
    enumeration(entry.kind, ['buff', 'debuff'], `statuses[${i}].kind`);
    enumeration(entry.stack, ['intensity', 'duration', 'none'], `statuses[${i}].stack`);
    enumeration(entry.decay, ['none', 'turn_end_minus_1', 'turn_start_trigger_then_minus_1', 'turn_end_trigger_then_minus_1'], `statuses[${i}].decay`);
  });
  lists.enemies.forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `enemies[${i}]`;
    enumeration(entry.tier, tiers, `${p}.tier`);
    integer(entry.hp, `${p}.hp`, 1);
    const intentIds = new Set();
    array(entry.intents, `${p}.intents`).forEach((intent, j) => {
      const ip = `${p}.intents[${j}]`;
      if (!object(intent, ip)) return;
      if (text(intent.id, `${ip}.id`)) {
        if (intentIds.has(intent.id)) fail(`${ip}.id`, `duplicate ID ${intent.id}`);
        intentIds.add(intent.id);
      }
      enumeration(intent.kind, ['attack', 'defend', 'buff', 'debuff'], `${ip}.kind`);
      effects(intent.effects, `${ip}.effects`);
    });
  });
  lists.encounters.forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `encounters[${i}]`;
    enumeration(entry.tier, tiers, `${p}.tier`);
    integer(entry.minFloor, `${p}.minFloor`, 1, 15);
    integer(entry.maxFloor, `${p}.maxFloor`, 1, 15);
    if (entry.minFloor > entry.maxFloor) fail(p, 'minFloor must not exceed maxFloor');
    array(entry.enemies, `${p}.enemies`).forEach((id, j) => reference(id, 'enemies', `${p}.enemies[${j}]`));
  });
  for (const kind of ['relics', 'potions']) lists[kind].forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `${kind}[${i}]`;
    enumeration(entry.rarity, kind === 'relics' ? ['starter', 'common', 'uncommon', 'rare'] : ['common', 'uncommon', 'rare'], `${p}.rarity`);
    if (kind === 'relics') enumeration(entry.trigger, ['combat_start', 'turn_start', 'combat_end'], `${p}.trigger`);
    effects(entry.effects, `${p}.effects`);
  });
  return errors;
}

export function loadContent(directory) {
  const bundle = {};
  for (const file of contentFiles) bundle[file] = JSON.parse(readFileSync(resolve(directory, `${file}.json`), 'utf8').replace(/^\uFEFF/, ''));
  return bundle;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const errors = validateContent(loadContent(process.argv[2] ?? 'data'));
    if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
    else console.log('Content validation passed (cards, statuses, enemies, encounters, relics, potions).');
  } catch (error) { console.error(`Content validation failed: ${error.message}`); process.exitCode = 1; }
}
