import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const recordFiles = ['cards', 'statuses', 'enemies', 'relics', 'potions'];
export const contentFiles = [...recordFiles, 'rules'];
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
  const keys = (value, allowed, path) => {
    for (const key of Object.keys(value)) if (!allowed.includes(key)) fail(`${path}.${key}`, 'unknown field');
  };
  const array = (value, path) => {
    if (!Array.isArray(value) || value.length === 0) { fail(path, 'must be a nonempty array'); return []; }
    return value;
  };
  if (!object(bundle, 'data')) return errors;
  const lists = {};
  for (const file of recordFiles) {
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
      const allowed = ['op'];
      if (valueOps.includes(op) || statusOps.includes(op) || op === 'addCardPerTurn') allowed.push('value');
      if (statusOps.includes(op) || op === 'gainTemporaryStrength') allowed.push('status');
      if (cardOps.includes(op)) allowed.push('card');
      if (op === 'conditional') allowed.push('if', 'then');
      if (['damage', 'damageAll'].includes(op)) allowed.push('times');
      if (op === 'discardRandom') allowed.push('mayChoose');
      keys(effect, allowed, p);
      if (valueOps.includes(op) || statusOps.includes(op) || op === 'addCardPerTurn') {
        const signed = statusOps.includes(op) && ['strength', 'dexterity'].includes(effect.status);
        integer(effect.value, `${p}.value`, signed ? Number.MIN_SAFE_INTEGER : 0);
      }
      if (statusOps.includes(op)) reference(effect.status, 'statuses', `${p}.status`);
      if (op === 'gainTemporaryStrength') {
        reference(effect.status, 'statuses', `${p}.status`);
        enumeration(effect.status, ['strength'], `${p}.status`);
      }
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
    if (!isObject(upgrade)) return;
    const allowed = ['cost', 'effects', 'type', 'rarity', 'condition', 'costMode', 'exhaust', 'ethereal', 'innate', 'repeatable'];
    keys(upgrade, allowed, path);
    if (!Object.keys(upgrade).some(key => allowed.includes(key))) fail(path, 'must change at least one field');
  }
  lists.cards.forEach((entry, i) => card(entry, `cards[${i}]`));
  const starter = bundle.cards?.starter_deck;
  if (object(starter, 'cards.starter_deck')) array(starter.cards, 'cards.starter_deck.cards').forEach((id, i) => reference(id, 'cards', `cards.starter_deck.cards[${i}]`));
  lists.statuses.forEach((entry, i) => {
    if (!isObject(entry)) return;
    enumeration(entry.kind, ['buff', 'debuff'], `statuses[${i}].kind`);
    enumeration(entry.stack, ['intensity', 'duration', 'none'], `statuses[${i}].stack`);
    enumeration(entry.decay, ['none', 'turn_end_minus_1', 'round_end_minus_1', 'turn_start_trigger_then_minus_1', 'turn_end_trigger_then_minus_1'], `statuses[${i}].decay`);
  });
  lists.enemies.forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `enemies[${i}]`;
    enumeration(entry.tier, tiers, `${p}.tier`);
    integer(entry.hp, `${p}.hp`, 1);
    if (entry.hpRange !== undefined && object(entry.hpRange, `${p}.hpRange`)) {
      keys(entry.hpRange, ['min', 'max'], `${p}.hpRange`);
      integer(entry.hpRange.min, `${p}.hpRange.min`, 1, 2147483647);
      integer(entry.hpRange.max, `${p}.hpRange.max`, 1, 2147483647);
      if (entry.hpRange.min > entry.hpRange.max) fail(`${p}.hpRange`, 'min must not exceed max');
      if (entry.hp < entry.hpRange.min || entry.hp > entry.hpRange.max) fail(`${p}.hp`, 'must lie within hpRange');
    }
    const intentIds = new Set();
    array(entry.intents, `${p}.intents`).forEach((intent, j) => {
      const ip = `${p}.intents[${j}]`;
      if (!object(intent, ip)) return;
      if (text(intent.id, `${ip}.id`)) {
        if (intentIds.has(intent.id)) fail(`${ip}.id`, `duplicate ID ${intent.id}`);
        intentIds.add(intent.id);
      }
      enumeration(intent.kind, ['attack', 'defend', 'buff', 'debuff', 'sleep', 'stunned', 'charge'], `${ip}.kind`);
      if (intent.kind === 'charge' && (entry.ai?.kind !== 'charge_then_attack' || entry.ai?.chargeIntent !== intent.id)) {
        fail(`${ip}.kind`, 'charge intent requires matching AI');
      }
      if (['sleep', 'stunned', 'charge'].includes(intent.kind)) {
        if (!Array.isArray(intent.effects) || intent.effects.length !== 0) fail(`${ip}.effects`, 'must be empty for an inactive intent');
      } else effects(intent.effects, `${ip}.effects`);
    });
    if (entry.ai !== undefined && object(entry.ai, `${p}.ai`)) {
      const a = entry.ai, ap = `${p}.ai`;
      const intentReference = (id, path, kind) => {
        if (text(id, path) && !intentIds.has(id)) fail(path, 'unknown intent ID');
        const intent = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === id);
        if (intent && (kind ? intent.kind !== kind : ['sleep', 'stunned', 'charge'].includes(intent.kind))) fail(path, 'invalid AI intent kind');
      };
      enumeration(a.kind, ['sleep_then_cycle', 'ritual_then_attack', 'guardian', 'jaw_worm', 'charge_then_attack', 'gremlin_nob', 'blue_slaver', 'acid_slime_s', 'rolled_attack'], `${ap}.kind`);
      if (a.kind === 'rolled_attack') {
        keys(a, ['kind', 'attackIntent', 'rollRange'], ap);
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
      } else if (a.kind === 'acid_slime_s') {
        keys(a, ['kind', 'tackleIntent', 'weakIntent', 'rollRange'], ap);
        intentReference(a.tackleIntent, `${ap}.tackleIntent`, 'attack');
        intentReference(a.weakIntent, `${ap}.weakIntent`, 'debuff');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
      } else if (a.kind === 'blue_slaver') {
        keys(a, ['kind', 'stabIntent', 'rakeIntent', 'rollRange', 'stabCutoff'], ap);
        intentReference(a.stabIntent, `${ap}.stabIntent`, 'attack');
        intentReference(a.rakeIntent, `${ap}.rakeIntent`, 'attack');
        if (a.stabIntent === a.rakeIntent) fail(ap, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.stabCutoff, `${ap}.stabCutoff`, 0, 65536);
        if (!(a.stabCutoff < a.rollRange)) fail(`${ap}.stabCutoff`, 'cutoff must be below rollRange');
      } else if (a.kind === 'gremlin_nob') {
        keys(a, ['kind', 'bellowIntent', 'bashIntent', 'rushIntent', 'rollRange', 'bashCutoff'], ap);
        intentReference(a.bellowIntent, `${ap}.bellowIntent`, 'buff');
        intentReference(a.bashIntent, `${ap}.bashIntent`, 'attack');
        intentReference(a.rushIntent, `${ap}.rushIntent`, 'attack');
        if (new Set([a.bellowIntent, a.bashIntent, a.rushIntent]).size !== 3) fail(ap, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.bashCutoff, `${ap}.bashCutoff`, 0, 65536);
        if (!(a.bashCutoff < a.rollRange)) fail(`${ap}.bashCutoff`, 'cutoff must be below rollRange');
        const opening = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.bellowIntent);
        if (!Array.isArray(opening?.effects) || !opening.effects.some(effect => effect?.op === 'gainStatus' && effect.status === 'enrage' && effect.value > 0)) {
          fail(`${ap}.bellowIntent`, 'must grant a positive Enrage stack');
        }
      } else if (a.kind === 'charge_then_attack') {
        keys(a, ['kind', 'initialCharge', 'chargeLimit', 'chargeIntent', 'attackIntent'], ap);
        integer(a.chargeLimit, `${ap}.chargeLimit`, 1, 2147483647);
        integer(a.initialCharge, `${ap}.initialCharge`, 0, Number.isInteger(a.chargeLimit) ? a.chargeLimit - 1 : 0);
        intentReference(a.chargeIntent, `${ap}.chargeIntent`, 'charge');
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
      } else if (a.kind === 'jaw_worm') {
        keys(a, ['kind', 'chompIntent', 'thrashIntent', 'bellowIntent', 'rollRange', 'chompCutoff', 'thrashCutoff',
          'bellowAfterChomp', 'chompAfterTwoThrashes', 'chompAfterBellow'], ap);
        intentReference(a.chompIntent, `${ap}.chompIntent`, 'attack');
        intentReference(a.thrashIntent, `${ap}.thrashIntent`, 'attack');
        intentReference(a.bellowIntent, `${ap}.bellowIntent`, 'buff');
        if (new Set([a.chompIntent, a.thrashIntent, a.bellowIntent]).size !== 3) fail(ap, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.chompCutoff, `${ap}.chompCutoff`, 0, 65536);
        integer(a.thrashCutoff, `${ap}.thrashCutoff`, 0, 65536);
        if (!(a.chompCutoff < a.thrashCutoff && a.thrashCutoff < a.rollRange)) fail(ap, 'invalid cutoff order');
        for (const key of ['bellowAfterChomp', 'chompAfterTwoThrashes', 'chompAfterBellow']) {
          if (typeof a[key] !== 'number' || !Number.isFinite(a[key]) || a[key] < 0 || a[key] > 1) fail(`${ap}.${key}`, 'must be a probability in 0..1');
        }
      } else if (a.kind === 'ritual_then_attack') {
        keys(a, ['kind', 'ritualIntent', 'attackIntent'], ap);
        intentReference(a.ritualIntent, `${ap}.ritualIntent`, 'buff');
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        const opening = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.ritualIntent);
        if (!Array.isArray(opening?.effects) || !opening.effects.some(effect => effect?.op === 'gainStatus' && effect.status === 'ritual' && effect.value > 0)) {
          fail(`${ap}.ritualIntent`, 'must grant a positive Ritual stack');
        }
      } else if (a.kind === 'guardian') {
        keys(a, ['kind', 'initialThreshold', 'thresholdIncrement', 'shiftBlock', 'offenseCycle', 'defenseCycle', 'returnIntent'], ap);
        integer(a.initialThreshold, `${ap}.initialThreshold`, 1, 2147483647);
        integer(a.thresholdIncrement, `${ap}.thresholdIncrement`, 1, 2147483647);
        integer(a.shiftBlock, `${ap}.shiftBlock`, 0, 999);
        for (const key of ['offenseCycle', 'defenseCycle']) {
          array(a[key], `${ap}.${key}`).forEach((id, j) => intentReference(id, `${ap}.${key}[${j}]`));
        }
        intentReference(a.returnIntent, `${ap}.returnIntent`);
        if (!Array.isArray(a.offenseCycle) || !a.offenseCycle.includes(a.returnIntent)) fail(`${ap}.returnIntent`, 'must occur in offenseCycle');
        reference('mode_shift', 'statuses', `${ap}.mode_shift`);
        reference('sharp_hide', 'statuses', `${ap}.sharp_hide`);
      } else if (a.kind === 'sleep_then_cycle') {
        keys(a, ['kind', 'sleepTurns', 'sleepBlock', 'sleepIntent', 'stunnedIntent', 'awakeCycle'], ap);
        integer(a.sleepTurns, `${ap}.sleepTurns`, 1);
        integer(a.sleepBlock, `${ap}.sleepBlock`, 0, 999);
        intentReference(a.sleepIntent, `${ap}.sleepIntent`, 'sleep');
        intentReference(a.stunnedIntent, `${ap}.stunnedIntent`, 'stunned');
        array(a.awakeCycle, `${ap}.awakeCycle`).forEach((id, j) => intentReference(id, `${ap}.awakeCycle[${j}]`));
      }
    }
  });
  lists.encounters.forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `encounters[${i}]`;
    enumeration(entry.tier, tiers, `${p}.tier`);
    integer(entry.minFloor, `${p}.minFloor`, 1, 16);
    integer(entry.maxFloor, `${p}.maxFloor`, 1, 16);
    if (entry.minFloor > entry.maxFloor) fail(p, 'minFloor must not exceed maxFloor');
    array(entry.enemies, `${p}.enemies`).forEach((id, j) => {
      reference(id, 'enemies', `${p}.enemies[${j}]`);
      const enemy = lists.enemies.find(candidate => isObject(candidate) && candidate.id === id);
      if (enemy && enemy.tier !== entry.tier) fail(`${p}.enemies[${j}]`, `enemy tier ${enemy.tier} does not match encounter tier ${entry.tier}`);
    });
  });
  // abyss_map forces these combat nodes; optional floors filter unavailable tiers.
  for (const [floor, tier] of [[1, 'normal'], [16, 'boss']]) {
    if (!lists.encounters.some(entry => isObject(entry) && entry.tier === tier &&
      Number.isSafeInteger(entry.minFloor) && Number.isSafeInteger(entry.maxFloor) &&
      entry.minFloor <= floor && entry.maxFloor >= floor)) {
      fail('enemies.encounters', `must include an eligible ${tier} encounter on forced floor ${floor}`);
    }
  }
  for (const kind of ['relics', 'potions']) lists[kind].forEach((entry, i) => {
    if (!isObject(entry)) return;
    const p = `${kind}[${i}]`;
    enumeration(entry.rarity, kind === 'relics' ? ['starter', 'common', 'uncommon', 'rare'] : ['common', 'uncommon', 'rare'], `${p}.rarity`);
    if (kind === 'relics') enumeration(entry.trigger, ['combat_start', 'turn_start', 'combat_end'], `${p}.trigger`);
    effects(entry.effects, `${p}.effects`);
  });
  const rules = bundle.rules;
  if (object(rules, 'rules.json')) {
    enumeration(rules.version, ['0.1.0'], 'rules.version');
    const numericSections = {
      player: { maxHp: [1], energyPerTurn: [1], drawPerTurn: [1], maxHand: [1], startingGold: [0], potionSlots: [1] },
      map: { floors: [17, 17], generatedRows: [15, 15], bossFloor: [16, 16],
        restFloor: [15, 15], treasureFloor: [9, 9], bossTreasureFloor: [17, 17] },
      camp: { healPercent: [1, 100], upgradeCount: [1] },
      shop: { cardCommon: [0], cardUncommon: [0], cardRare: [0], relic: [0], removeCard: [0], removeCardIncrement: [0] },
      rewards: { normalGold: [0], eliteGold: [0], bossGold: [0], cardChoices: [1] },
      combat: { vulnerablePercent: [0], weakPercent: [0], frailPercent: [0] }
    };
    for (const [section, fields] of Object.entries(numericSections)) {
      if (!object(rules[section], `rules.${section}`)) continue;
      for (const [field, bounds] of Object.entries(fields)) integer(rules[section][field], `rules.${section}.${field}`, ...bounds);
    }
    if (isObject(rules.player)) {
      array(rules.player.startingRelics, 'rules.player.startingRelics').forEach((id, i) => reference(id, 'relics', `rules.player.startingRelics[${i}]`));
      if (rules.player.drawPerTurn > rules.player.maxHand) fail('rules.player.drawPerTurn', 'must not exceed maxHand');
    }
    if (object(rules.events, 'rules.events')) {
      enumeration(rules.events.encounterId, ['cleric', 'purifier'], 'rules.events.encounterId');
      if (object(rules.events.purifier, 'rules.events.purifier')) integer(rules.events.purifier.removeCost, 'rules.events.purifier.removeCost', 0, 0);
    }
    if (isObject(rules.events) && object(rules.events.cleric, 'rules.events.cleric')) {
      for (const field of ['minGold', 'healCost', 'removeCost']) integer(rules.events.cleric[field], `rules.events.cleric.${field}`, 0);
      integer(rules.events.cleric.healPercent, 'rules.events.cleric.healPercent', 1, 100);
      if (rules.events.cleric.minGold !== rules.events.cleric.healCost) fail('rules.events.cleric.minGold', 'must equal the cost of the first affordable option');
    }
    if (isObject(rules.map)) {
      const required = ['combat', 'elite', 'camp', 'shop', 'event', 'treasure', 'boss'];
      const nodes = array(rules.map.nodeTypes, 'rules.map.nodeTypes');
      nodes.forEach((node, i) => enumeration(node, required, `rules.map.nodeTypes[${i}]`));
      if (nodes.length !== required.length || new Set(nodes).size !== required.length || required.some(node => !nodes.includes(node))) fail('rules.map.nodeTypes', 'must contain all seven node types exactly once');
    }
    if (isObject(rules.combat)) {
      for (const [key, expected] of Object.entries({ blockReset: 'owner_turn_start', rounding: 'floor_after_modifiers', enemyAI: 'intent_cycle', statusDurationTick: 'round_end' })) enumeration(rules.combat[key], [expected], `rules.combat.${key}`);
      if (typeof rules.combat.poisonBypassesBlock !== 'boolean') fail('rules.combat.poisonBypassesBlock', 'must be boolean');
    }
  }
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
    else console.log('Content validation passed (cards, statuses, enemies, encounters, relics, potions, rules).');
  } catch (error) { console.error(`Content validation failed: ${error.message}`); process.exitCode = 1; }
}
