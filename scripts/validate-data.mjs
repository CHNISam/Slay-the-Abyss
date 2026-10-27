import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const recordFiles = ['cards', 'statuses', 'enemies', 'relics', 'potions'];
export const contentFiles = [...recordFiles, 'rules'];
const tiers = ['normal', 'elite', 'boss'];
const valueOps = ['fatalRevive', 'discover', 'generatePotions', 'damage', 'damageAll', 'block', 'draw', 'energy', 'loseHp', 'heal', 'healPercent', 'increaseMaxHp',
  'blockPerTurn', 'discardRandom', 'increaseDamageThisCombat', 'gainTemporaryStrength', 'gainTemporaryDexterity',
  'exhaustRandom', 'exhaustChoose', 'putOnDrawPile'];
const statusOps = ['gainStatus', 'applyStatus', 'applyStatusAll', 'gainStatusPerTurn'];
const cardOps = ['addCardToDiscard', 'addCardPerTurn', 'makeTempCardInDiscard'];
const flagOps = ['damageEqualToBlock', 'doubleBlock', 'noDrawThisTurn', 'healEqualToDamageDealt'];
const actionOps = ['exhaustRandom','exhaustChoose','exhaustNonAttacks','secondWind','fiendFire',
  'exhaustMany','discardRedraw','discardToHand','randomizeHandCost','escape','playTopCards',
  'recoverExhaust','upgradeHand','discardToDraw','handToDraw','dualWield','generateAttack',
  'makeTempCardInHand','makeTempCardInDraw','doubleStrength','spotWeakness','feed','reaper','playTop','damageRandom'];
const actionValues = ['exhaustMany','discardRedraw','discardToHand','randomizeHandCost','escape','playTopCards','secondWind','fiendFire','dualWield','makeTempCardInHand','makeTempCardInDraw','spotWeakness','feed','reaper','damageRandom','generateAttack'];
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
  // A bounded opt-in pair, not a general target/effect DSL. Walk all own
  // values so falsey, sparse, container and unreachable nested markers fail.
  function targetGroup(value, path, cardEffects) {
    let found = false, misplaced = false, cyclic = false;
    const seen = new Set(), active = new Set();
    const pending = [{node: value, topMember: false}];
    while (pending.length) {
      const {node, topMember, leaving} = pending.pop();
      if (node === null || typeof node !== 'object') continue;
      if (leaving) { active.delete(node); continue; }
      if (Object.hasOwn(node, 'targetGroup')) {
        found = true;
        if (!topMember) misplaced = true;
      }
      if (active.has(node)) { cyclic = true; continue; }
      if (seen.has(node)) continue;
      seen.add(node); active.add(node);
      pending.push({node, leaving: true});
      for (const [key, child] of Object.entries(node)) {
        pending.push({node: child, topMember: node === value && /^(0|[1-9][0-9]*)$/.test(key)});
      }
    }
    if (!found) return;
    const invalid = () => fail(`${path}.targetGroup`, 'invalid target group');
    if (!cardEffects || misplaced || cyclic || !Array.isArray(value)
      || Object.keys(value).length !== value.length
      || Object.keys(value).some((key, i) => key !== String(i))) { invalid(); return; }
    const members = [];
    for (let i = 0; i < value.length; i++) {
      const effect = value[i];
      if (!isObject(effect)) { invalid(); return; }
      if (!Object.hasOwn(effect, 'targetGroup')) continue;
      if (effect.targetGroup !== 'weak_then_vulnerable' || effect.op !== 'applyStatusAll'
        || !Number.isInteger(effect.value) || effect.value < 1 || effect.value > 2147483647
        || Object.keys(effect).some(key => !['op','status','value','targetGroup'].includes(key))) { invalid(); return; }
      members.push(i);
    }
    if (members.length !== 2 || members[1] !== members[0] + 1
      || value[members[0]].status !== 'weak' || value[members[1]].status !== 'vulnerable'
      || value[members[0]].value !== value[members[1]].value) invalid();
  }
  function effects(value, path, depth = 0, enemyIntent = false, cardEffects = false) {
    if (depth > 8) { fail(path, 'conditional nesting exceeds 8'); return; }
    targetGroup(value, path, cardEffects && depth === 0);
    array(value, path).forEach((effect, i) => {
      const p = `${path}[${i}]`;
      if (!object(effect, p)) return;
      const op = effect.op;
      if (!enumeration(op, [...valueOps, ...statusOps, ...cardOps, ...flagOps, ...actionOps, 'conditional'], `${p}.op`)) return;
      const allowed = ['op'];
      if (cardEffects && depth === 0) allowed.push('targetGroup');
      if (actionValues.includes(op)) allowed.push('value');
      if (['makeTempCardInHand','makeTempCardInDraw'].includes(op)) allowed.push('card');
      if (op === 'upgradeHand') allowed.push('all');
      if (op === 'discover') allowed.push('kind');
      if (op === 'feed') allowed.push('maxHp');
      if (op === 'damageRandom') allowed.push('times');
      if (valueOps.includes(op) || statusOps.includes(op) || ['addCardPerTurn', 'makeTempCardInDiscard'].includes(op)) allowed.push('value');
      if (statusOps.includes(op) || ['gainTemporaryStrength', 'gainTemporaryDexterity'].includes(op)) allowed.push('status');
      if (cardOps.includes(op)) allowed.push('card');
      if (op === 'conditional') allowed.push('if', 'then');
      if (['damage', 'damageAll'].includes(op)) allowed.push('times');
      if (op === 'discardRandom') allowed.push('mayChoose');
      if (op === 'block' && enemyIntent) allowed.push('target');
      keys(effect, allowed, p);
      if (op === 'discover') enumeration(effect.kind, ['attack','skill','power','colorless'], `${p}.kind`);
      if (effect.target !== undefined) enumeration(effect.target, ['random_ally'], `${p}.target`);
      if (valueOps.includes(op) || statusOps.includes(op) || ['addCardPerTurn', 'makeTempCardInDiscard'].includes(op)) {
        const signed = statusOps.includes(op) && ['strength', 'dexterity'].includes(effect.status);
        integer(effect.value, `${p}.value`, signed ? Number.MIN_SAFE_INTEGER : 0, op === 'makeTempCardInDiscard' ? 5 : Number.MAX_SAFE_INTEGER);
      }
      if (statusOps.includes(op)) reference(effect.status, 'statuses', `${p}.status`);
      if (op === 'gainTemporaryStrength' || op === 'gainTemporaryDexterity') {
        reference(effect.status, 'statuses', `${p}.status`);
        enumeration(effect.status, [op === 'gainTemporaryStrength' ? 'strength' : 'dexterity'], `${p}.status`);
      }
      if (cardOps.includes(op)) reference(effect.card, 'cards', `${p}.card`);
      if (actionValues.includes(op)) integer(effect.value, `${p}.value`, 0, 2147483647);
      if (['makeTempCardInHand','makeTempCardInDraw'].includes(op)) reference(effect.card, 'cards', `${p}.card`);
      if (effect.all !== undefined && typeof effect.all !== 'boolean') fail(`${p}.all`, 'must be boolean');
      if (op === 'feed') integer(effect.maxHp, `${p}.maxHp`, 1, 2147483647);
      if (effect.times !== undefined && effect.times !== 'X') integer(effect.times, `${p}.times`, 1);
      if (effect.mayChoose !== undefined && typeof effect.mayChoose !== 'boolean') fail(`${p}.mayChoose`, 'must be boolean');
      if (op === 'conditional') {
        enumeration(effect.if, ['target_vulnerable'], `${p}.if`);
        effects(effect.then, `${p}.then`, depth + 1);
      }
    });
  }
  function card(card, path, partial = false) {
    if (!object(card, path)) return;
    const curse = !partial && ['regret','injury','doubt','pain','decay','shame','writhe','clumsy','normality','parasite'].includes(card.id);
    if (!partial || card.type !== undefined) enumeration(card.type, ['attack', 'skill', 'power', 'status', 'curse'], `${path}.type`);
    if (!partial || card.rarity !== undefined) enumeration(card.rarity, curse ? ['curse'] : ['basic', 'common', 'uncommon', 'rare', 'special'], `${path}.rarity`);
    const unplayableStatus = !partial && card.type === 'status' && card.cost === -2;
    const slimed = !partial && card.id === 'slimed';
    if (curse || slimed || unplayableStatus) targetGroup(card.effects, `${path}.effects`, false);
    if (!unplayableStatus && !curse && (!partial || card.cost !== undefined)) integer(card.cost, `${path}.cost`, 0, 5);
    if (curse) {
      enumeration(card.type, ['curse'], `${path}.type`);
      enumeration(card.cost, [-2], `${path}.cost`);
      if (!Array.isArray(card.effects) || card.effects.length !== 0) fail(`${path}.effects`, 'basic curse must have empty ordinary use');
      for (const flag of ['exhaust', 'repeatable']) {
        if (card[flag]) fail(`${path}.${flag}`, 'basic curse does not support this flag');
      }
      if ((card.ethereal === true) !== (card.id === 'clumsy')) fail(`${path}.ethereal`, 'only Clumsy is ethereal');
      if ((card.innate === true) !== (card.id === 'writhe')) fail(`${path}.innate`, 'only Writhe is innate');
      if (card.id === 'decay') enumeration(card.endTurnDamage, [2], `${path}.endTurnDamage`);
      const curseValues = {endTurnStatusAmount: ['doubt','shame'].includes(card.id) ? 1 : undefined,
        onOtherCardHpLoss: card.id === 'pain' ? 1 : undefined, playLimit: card.id === 'normality' ? 3 : undefined,
        onRemoveMaxHpLoss: card.id === 'parasite' ? 3 : undefined};
      for (const [field, value] of Object.entries(curseValues)) {
        if (card[field] !== value) fail(`${path}.${field}`, 'must match the source basic curse lifecycle');
      }
      for (const field of ['costMode', 'condition', 'upgrade']) {
        if (card[field] !== undefined) fail(`${path}.${field}`, 'basic curse does not support this field');
      }
    } else if (slimed) {
      enumeration(card.type, ['status'], `${path}.type`);
      enumeration(card.cost, [1], `${path}.cost`);
      enumeration(card.exhaust, [true], `${path}.exhaust`);
      if (!Array.isArray(card.effects) || card.effects.length !== 0) fail(`${path}.effects`, 'Slimed must have empty use');
      if (card.ethereal) fail(`${path}.ethereal`, 'Slimed is not ethereal');
      for (const field of ['costMode', 'condition', 'upgrade']) {
        if (card[field] !== undefined) fail(`${path}.${field}`, 'Slimed does not support this field');
      }
    } else if (unplayableStatus) {
      if (!Array.isArray(card.effects) || card.effects.length !== 0) fail(`${path}.effects`, 'unplayable status must have empty use');
      if (card.costMode !== undefined) fail(`${path}.costMode`, 'unplayable status has no cost mode');
      if (card.upgrade !== undefined) fail(`${path}.upgrade`, 'unplayable status upgrades are unsupported');
    } else if (!partial || card.effects !== undefined) effects(card.effects, `${path}.effects`, 0, false, true);
    if (card.condition !== undefined) enumeration(card.condition, ['only_attacks_in_hand'], `${path}.condition`);
    if (card.costMode !== undefined) enumeration(card.costMode, ['all_energy'], `${path}.costMode`);
    if (card.target !== undefined) enumeration(card.target,['ENEMY','SELF','NONE','ALL_ENEMY','SELF_AND_ENEMY'],`${path}.target`);
    for (const flag of ['strikeTag','healing']) if (card[flag] !== undefined && typeof card[flag] !== 'boolean') fail(`${path}.${flag}`,'must be boolean');
    for (const field of ['strikeBonus','strengthMultiplier','exhaustEnergy','endTurnDamage']) if (card[field] !== undefined) integer(card[field],`${path}.${field}`,1,2147483647);
    for (const flag of ['exhaust', 'ethereal', 'innate', 'repeatable']) {
      if (card[flag] !== undefined && typeof card[flag] !== 'boolean') fail(`${path}.${flag}`, 'must be boolean');
    }
    if (card.upgrade !== undefined && !partial) cardUpgrade(card.upgrade, `${path}.upgrade`);
  }
  function cardUpgrade(upgrade, path) {
    card(upgrade, path, true);
    if (!isObject(upgrade)) return;
    const allowed = ['cost', 'effects', 'type', 'rarity', 'condition', 'costMode', 'exhaust', 'ethereal', 'innate', 'repeatable','strengthMultiplier','strikeBonus','exhaustEnergy'];
    keys(upgrade, allowed, path);
    if (!Object.keys(upgrade).some(key => allowed.includes(key))) fail(path, 'must change at least one field');
  }
  lists.cards.forEach((entry, i) => card(entry, `cards[${i}]`));
  const pools = bundle.cards.sourcePools;
  if (object(pools, 'cards.sourcePools')) {
    const classCards=lists.cards.filter(c=>c.type!=='status' && c.type!=='curse' && c.rarity!=='basic');
    const byId=new Map(classCards.map(c=>[c.id,c]));
    for (const kind of ['reward','src']) {
      const seen=new Set();
      if (!object(pools[kind], `cards.sourcePools.${kind}`)) continue;
      for (const rarity of ['common','uncommon','rare']) {
        const list=pools[kind][rarity];
        if (!Array.isArray(list)) { fail(`cards.sourcePools.${kind}.${rarity}`,'must be an array'); continue; }
        for (const [i,id] of list.entries()) {
          const path=`cards.sourcePools.${kind}.${rarity}[${i}]`;
          if (!byId.has(id) || byId.get(id).rarity!==rarity) fail(path,'must be a class card of this rarity');
          if (seen.has(id)) fail(path,'duplicate class card');
          seen.add(id);
        }
      }
      for (const c of classCards) if (!seen.has(c.id)) fail(`cards.sourcePools.${kind}`,`missing class card ${c.id}`);
    }
    if (object(pools.shop,'cards.sourcePools.shop')) {
      const seen=new Set();
      for (const rarity of ['common','uncommon','rare']) {
       if (!object(pools.shop[rarity],`cards.sourcePools.shop.${rarity}`)) continue;
       for (const type of ['attack','skill','power']) {
        const list=pools.shop[rarity][type];
        if (!Array.isArray(list)) { fail(`cards.sourcePools.shop.${rarity}.${type}`,'must be an array'); continue; }
        let previous;
        for (const [i,id] of list.entries()) {
          const path=`cards.sourcePools.shop.${rarity}.${type}[${i}]`, c=byId.get(id);
          if (!c || c.type!==type || c.rarity!==rarity) fail(path,'must be a class card of this type and rarity');
          if (seen.has(id)) fail(path,'duplicate class card');
          if (c && (typeof c.sourceId!=='string' || previous!==undefined && previous>=c.sourceId)) fail(path,'must be ordered by unique original card ID');
          if (c) previous=c.sourceId;
          seen.add(id);
        }
       }
      }
      for (const c of classCards) if (!seen.has(c.id)) fail('cards.sourcePools.shop',`missing class card ${c.id}`);
    }
  }
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
      enumeration(intent.kind, ['attack', 'defend', 'buff', 'debuff', 'sleep', 'stunned', 'charge', 'split', 'escape'], `${ip}.kind`);
      if (intent.kind === 'escape' && (entry.ai?.kind !== 'looter' || entry.ai?.escapeIntent !== intent.id)) {
        fail(`${ip}.kind`, 'escape intent requires matching Looter AI');
      }
      if (intent.kind === 'charge' && (entry.ai?.kind !== 'charge_then_attack' || entry.ai?.chargeIntent !== intent.id)) {
        fail(`${ip}.kind`, 'charge intent requires matching AI');
      }
      if (intent.kind === 'split' && (!['spike_slime_l', 'acid_slime_l'].includes(entry.ai?.kind) || entry.ai?.splitIntent !== intent.id)) {
        fail(`${ip}.kind`, 'split intent requires matching AI');
      }
      if (['sleep', 'stunned', 'charge', 'split', 'escape'].includes(intent.kind)) {
        targetGroup(intent.effects, `${ip}.effects`, false);
        if (!Array.isArray(intent.effects) || intent.effects.length !== 0) fail(`${ip}.effects`, 'must be empty for an inactive intent');
      } else effects(intent.effects, `${ip}.effects`, 0, true);
    });
    if (entry.ai !== undefined && object(entry.ai, `${p}.ai`)) {
      const a = entry.ai, ap = `${p}.ai`;
      const intentReference = (id, path, kind) => {
        if (text(id, path) && !intentIds.has(id)) fail(path, 'unknown intent ID');
        const intent = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === id);
        if (intent && (kind ? intent.kind !== kind : ['sleep', 'stunned', 'charge', 'split', 'escape'].includes(intent.kind))) fail(path, 'invalid AI intent kind');
      };
      enumeration(a.kind, ['sleep_then_cycle', 'ritual_then_attack', 'guardian', 'jaw_worm', 'charge_then_attack', 'gremlin_nob', 'blue_slaver', 'red_slaver', 'acid_slime_s', 'rolled_attack', 'opening_roll_attack', 'sentry', 'mad_gremlin', 'shield_gremlin', 'spike_slime_m', 'spike_slime_l', 'acid_slime_m', 'acid_slime_l', 'fungi_beast', 'louse', 'looter'], `${ap}.kind`);
      if (a.kind === 'looter') {
        keys(a, ['kind', 'mugIntent', 'lungeIntent', 'smokeIntent', 'escapeIntent', 'stealAmount', 'rollRange', 'talkChance', 'smokeChance'], ap);
        reference('thievery', 'statuses', `${ap}.thievery`);
        for (const [key, kind] of [['mugIntent','attack'], ['lungeIntent','attack'], ['smokeIntent','defend'], ['escapeIntent','escape']]) intentReference(a[key], `${ap}.${key}`, kind);
        for (const [key, value] of [['stealAmount',15], ['rollRange',100], ['talkChance',Math.fround(0.6)], ['smokeChance',0.5]]) {
          if (a[key] !== value) fail(`${ap}.${key}`, `must match source A0 value ${value}`);
        }
        for (const [key, op, value] of [['mugIntent','damage',10], ['lungeIntent','damage',12], ['smokeIntent','block',6]]) {
          const move = Array.isArray(entry.intents) && entry.intents.find(x => x?.id === a[key]);
          if (move && (move.effects?.length !== 1 || move.effects[0]?.op !== op || move.effects[0]?.value !== value || Object.keys(move.effects[0] ?? {}).sort().join(',') !== 'op,value')) fail(`${ap}.${key}`, 'must match the single source A0 effect');
        }
      } else if (a.kind === 'louse') {
        keys(a, ['kind', 'biteIntent', 'supportIntent', 'rollRange', 'supportCutoff', 'biteRange', 'curlUpRange'], ap);
        reference('curl_up', 'statuses', `${ap}.curl_up`);
        if (object(a.curlUpRange, `${ap}.curlUpRange`)) {
          keys(a.curlUpRange, ['min', 'max'], `${ap}.curlUpRange`);
          integer(a.curlUpRange.min, `${ap}.curlUpRange.min`, 1, 2147483647);
          integer(a.curlUpRange.max, `${ap}.curlUpRange.max`, 1, 2147483647);
          if (a.curlUpRange.min > a.curlUpRange.max) fail(`${ap}.curlUpRange`, 'min must not exceed max');
          if (a.curlUpRange.max - a.curlUpRange.min + 1 > 65536) fail(`${ap}.curlUpRange`, 'sampling range must not exceed 65536');
        }
        intentReference(a.biteIntent, `${ap}.biteIntent`, 'attack');
        intentReference(a.supportIntent, `${ap}.supportIntent`);
        const support = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.supportIntent);
        if (support && !['buff', 'debuff'].includes(support.kind)) fail(`${ap}.supportIntent`, 'must be a buff or debuff');
        if (a.biteIntent === a.supportIntent) fail(`${ap}.supportIntent`, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.supportCutoff, `${ap}.supportCutoff`, 0, 65536);
        if (!(a.supportCutoff < a.rollRange)) fail(`${ap}.supportCutoff`, 'cutoff must be below rollRange');
        if (object(a.biteRange, `${ap}.biteRange`)) {
          keys(a.biteRange, ['min', 'max'], `${ap}.biteRange`);
          integer(a.biteRange.min, `${ap}.biteRange.min`, 1, 2147483647);
          integer(a.biteRange.max, `${ap}.biteRange.max`, 1, 2147483647);
          if (a.biteRange.min > a.biteRange.max) fail(`${ap}.biteRange`, 'min must not exceed max');
          if (a.biteRange.max - a.biteRange.min + 1 > 65536) fail(`${ap}.biteRange`, 'sampling range must not exceed 65536');
        }
        const bite = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.biteIntent);
        const payload = bite?.effects;
        if (!Array.isArray(payload) || payload.length !== 1 || payload[0]?.op !== 'damage'
          || Object.keys(payload[0]).some(key => !['op', 'value'].includes(key))) {
          fail(`${ap}.biteIntent`, 'must contain exactly one ordinary damage effect');
        }
      } else if (a.kind === 'fungi_beast') {
        keys(a, ['kind', 'biteIntent', 'growIntent', 'rollRange', 'biteCutoff', 'sporeCloudStacks'], ap);
        integer(a.sporeCloudStacks, `${ap}.sporeCloudStacks`, 1, 2147483647);
        reference('spore_cloud', 'statuses', `${ap}.spore_cloud`);
        intentReference(a.biteIntent, `${ap}.biteIntent`, 'attack');
        intentReference(a.growIntent, `${ap}.growIntent`, 'buff');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.biteCutoff, `${ap}.biteCutoff`, 0, 65536);
        if (!(a.biteCutoff < a.rollRange)) fail(`${ap}.biteCutoff`, 'cutoff must be below rollRange');
      } else if (a.kind === 'acid_slime_m' || a.kind === 'acid_slime_l') {
        const splitKeys = a.kind === 'acid_slime_l' ? ['splitIntent', 'splitEnemy', 'splitCount', 'splitHpDivisor'] : [];
        keys(a, ['kind', 'spitIntent', 'weakIntent', 'tackleIntent', 'rollRange', 'spitCutoff', 'tackleCutoff', 'spitChance', ...splitKeys], ap);
        if (a.kind === 'acid_slime_l') {
          intentReference(a.splitIntent, `${ap}.splitIntent`, 'split');
          enumeration(a.splitEnemy, ['acid_slime_m'], `${ap}.splitEnemy`);
          reference(a.splitEnemy, 'enemies', `${ap}.splitEnemy`);
          const child = lists.enemies.find(e => isObject(e) && e.id === a.splitEnemy);
          if (child?.ai?.kind !== 'acid_slime_m') fail(`${ap}.splitEnemy`, 'requires the supported medium policy');
          integer(a.splitCount, `${ap}.splitCount`, 2, 2);
          integer(a.splitHpDivisor, `${ap}.splitHpDivisor`, 2, 2);
        }
        intentReference(a.spitIntent, `${ap}.spitIntent`, 'attack');
        intentReference(a.weakIntent, `${ap}.weakIntent`, 'debuff');
        intentReference(a.tackleIntent, `${ap}.tackleIntent`, 'attack');
        if (new Set([a.spitIntent, a.weakIntent, a.tackleIntent]).size !== 3) fail(`${ap}.tackleIntent`, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.spitCutoff, `${ap}.spitCutoff`, 0, 65536);
        integer(a.tackleCutoff, `${ap}.tackleCutoff`, 0, 65536);
        if (!(a.spitCutoff < a.tackleCutoff)) fail(`${ap}.spitCutoff`, 'cutoffs must be strictly increasing');
        if (!(a.tackleCutoff < a.rollRange)) fail(`${ap}.tackleCutoff`, 'cutoff must be below rollRange');
        if (typeof a.spitChance !== 'number' || !Number.isFinite(a.spitChance) || a.spitChance < 0 || a.spitChance > 1) fail(`${ap}.spitChance`, 'must be a probability in 0..1');
        const spit = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.spitIntent);
        const payload = spit?.effects;
        const slimedCount = a.kind === 'acid_slime_l' ? 2 : 1;
        if (!Array.isArray(payload) || payload.length !== 2 || payload[0]?.op !== 'damage'
          || payload[1]?.op !== 'makeTempCardInDiscard' || payload[1].card !== 'slimed' || payload[1].value !== slimedCount) {
          fail(`${ap}.spitIntent`, `must contain damage followed by exactly ${slimedCount} Slimed creation`);
        }
      } else if (a.kind === 'spike_slime_m' || a.kind === 'spike_slime_l') {
        const splitKeys = a.kind === 'spike_slime_l' ? ['splitIntent', 'splitEnemy', 'splitCount', 'splitHpDivisor'] : [];
        keys(a, ['kind', 'tackleIntent', 'frailIntent', 'rollRange', 'tackleCutoff', ...splitKeys], ap);
        if (a.kind === 'spike_slime_l') {
          intentReference(a.splitIntent, `${ap}.splitIntent`, 'split');
          enumeration(a.splitEnemy, ['spike_slime_m'], `${ap}.splitEnemy`);
          reference(a.splitEnemy, 'enemies', `${ap}.splitEnemy`);
          const child = lists.enemies.find(e => isObject(e) && e.id === a.splitEnemy);
          if (child?.ai?.kind !== 'spike_slime_m') fail(`${ap}.splitEnemy`, 'requires the supported medium policy');
          integer(a.splitCount, `${ap}.splitCount`, 2, 2);
          integer(a.splitHpDivisor, `${ap}.splitHpDivisor`, 2, 2);
        }
        intentReference(a.tackleIntent, `${ap}.tackleIntent`, 'attack');
        intentReference(a.frailIntent, `${ap}.frailIntent`, 'debuff');
        if (a.tackleIntent === a.frailIntent) fail(ap, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.tackleCutoff, `${ap}.tackleCutoff`, 0, 65536);
        if (!(a.tackleCutoff < a.rollRange)) fail(`${ap}.tackleCutoff`, 'cutoff must be below rollRange');
        const tackle = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.tackleIntent);
        const payload = tackle?.effects;
        const slimedCount = a.kind === 'spike_slime_l' ? 2 : 1;
        if (!Array.isArray(payload) || payload.length !== 2 || payload[0]?.op !== 'damage'
          || payload[1]?.op !== 'makeTempCardInDiscard' || payload[1].card !== 'slimed' || payload[1].value !== slimedCount) {
          fail(`${ap}.tackleIntent`, `must contain damage followed by exactly ${slimedCount} Slimed creation`);
        }
      } else if (a.kind === 'shield_gremlin') {
        keys(a, ['kind', 'protectIntent', 'attackIntent', 'rollRange'], ap);
        intentReference(a.protectIntent, `${ap}.protectIntent`, 'defend');
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        const protect = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.protectIntent);
        if (!Array.isArray(protect?.effects) || !protect.effects.some(effect => effect?.op === 'block' && effect.target === 'random_ally' && effect.value > 0)) {
          fail(`${ap}.protectIntent`, 'must grant Block to a random ally with a solo fallback');
        }
      } else if (a.kind === 'mad_gremlin') {
        keys(a, ['kind', 'attackIntent', 'rollRange', 'angryStacks'], ap);
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        integer(a.angryStacks, `${ap}.angryStacks`, 1, 2147483647);
        reference('angry', 'statuses', `${ap}.angry`);
      } else if (a.kind === 'sentry') {
        keys(a, ['kind', 'beamIntent', 'boltIntent', 'artifactStacks', 'rollRange'], ap);
        intentReference(a.beamIntent, `${ap}.beamIntent`, 'attack');
        intentReference(a.boltIntent, `${ap}.boltIntent`, 'debuff');
        integer(a.artifactStacks, `${ap}.artifactStacks`, 1, 2147483647);
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        reference('artifact', 'statuses', `${ap}.artifact`);
        const bolt = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.boltIntent);
        if (!Array.isArray(bolt?.effects) || !bolt.effects.some(effect => effect?.op === 'makeTempCardInDiscard' && effect.card === 'dazed' && effect.value > 0)) {
          fail(`${ap}.boltIntent`, 'must generate Dazed cards, never a substitute Power');
        }
      } else if (a.kind === 'rolled_attack' || a.kind === 'opening_roll_attack') {
        keys(a, ['kind', 'attackIntent', 'rollRange'], ap);
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
      } else if (a.kind === 'acid_slime_s') {
        keys(a, ['kind', 'tackleIntent', 'weakIntent', 'rollRange'], ap);
        intentReference(a.tackleIntent, `${ap}.tackleIntent`, 'attack');
        intentReference(a.weakIntent, `${ap}.weakIntent`, 'debuff');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
      } else if (a.kind === 'red_slaver') {
        keys(a, ['kind', 'stabIntent', 'entangleIntent', 'scrapeIntent', 'rollRange', 'entangleCutoff', 'stabCutoff'], ap);
        intentReference(a.stabIntent, `${ap}.stabIntent`, 'attack');
        intentReference(a.entangleIntent, `${ap}.entangleIntent`, 'debuff');
        intentReference(a.scrapeIntent, `${ap}.scrapeIntent`, 'attack');
        if (new Set([a.stabIntent, a.entangleIntent, a.scrapeIntent]).size !== 3) fail(ap, 'move intents must be distinct');
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        for (const cutoff of ['entangleCutoff', 'stabCutoff']) {
          integer(a[cutoff], `${ap}.${cutoff}`, 0, 65536);
          if (!(a[cutoff] < a.rollRange)) fail(`${ap}.${cutoff}`, 'cutoff must be below rollRange');
        }
        const net = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.entangleIntent);
        if (!Array.isArray(net?.effects) || !net.effects.some(effect => effect?.op === 'applyStatus' && effect.status === 'entangled' && effect.value === 1)) {
          fail(`${ap}.entangleIntent`, 'must apply Entangled one');
        }
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
        keys(a, ['kind', 'initialCharge', 'chargeLimit', 'chargeIntent', 'attackIntent', 'rollRange'], ap);
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
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
        keys(a, ['kind', 'ritualIntent', 'attackIntent', 'rollRange'], ap);
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
        intentReference(a.ritualIntent, `${ap}.ritualIntent`, 'buff');
        intentReference(a.attackIntent, `${ap}.attackIntent`, 'attack');
        const opening = Array.isArray(entry.intents) && entry.intents.find(intent => intent?.id === a.ritualIntent);
        if (!Array.isArray(opening?.effects) || !opening.effects.some(effect => effect?.op === 'gainStatus' && effect.status === 'ritual' && effect.value > 0)) {
          fail(`${ap}.ritualIntent`, 'must grant a positive Ritual stack');
        }
      } else if (a.kind === 'guardian') {
        keys(a, ['kind', 'initialThreshold', 'thresholdIncrement', 'shiftBlock', 'offenseCycle', 'defenseCycle', 'returnIntent', 'rollRange'], ap);
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
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
        keys(a, ['kind', 'sleepTurns', 'sleepBlock', 'sleepIntent', 'stunnedIntent', 'awakeCycle', 'rollRange'], ap);
        integer(a.rollRange, `${ap}.rollRange`, 1, 65536);
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
    const gremlin = entry.id === 'gremlin_gang';
    const louseCount = entry.id === 'louse_pair' ? 2 : entry.id === 'louse_trio' ? 3 : 0;
    if (louseCount) {
      integer(entry.louseCount, `${p}.louseCount`, louseCount, louseCount);
      if (!Array.isArray(entry.lousePool) || entry.lousePool.length !== 2
          || entry.lousePool[0] !== 'red_louse' || entry.lousePool[1] !== 'green_louse') {
        fail(`${p}.lousePool`, 'must match the ordered red_louse, green_louse source pool');
      }
      for (const field of ['enemies', 'enemiesOnTrue']) {
        if (entry[field] !== undefined) fail(`${p}.${field}`, 'cannot coexist with lousePool');
      }
    } else {
      for (const field of ['lousePool', 'louseCount']) {
        if (entry[field] !== undefined) fail(`${p}.${field}`, 'is only supported by louse_pair and louse_trio');
      }
    }
    const sourcePool = ['mad_gremlin', 'mad_gremlin', 'sneaky_gremlin', 'sneaky_gremlin',
      'fat_gremlin', 'fat_gremlin', 'shield_gremlin', 'wizard_gremlin'];
    if (gremlin) {
      integer(entry.gremlinCount, `${p}.gremlinCount`, 4, 4);
      if (!Array.isArray(entry.gremlinPool) || entry.gremlinPool.length !== sourcePool.length
          || sourcePool.some((id, j) => entry.gremlinPool[j] !== id)) {
        fail(`${p}.gremlinPool`, 'must match the ordered eight-item source pool');
      }
      for (const field of ['enemies', 'enemiesOnTrue']) {
        if (entry[field] !== undefined) fail(`${p}.${field}`, 'cannot coexist with gremlinPool');
      }
    } else {
      for (const field of ['gremlinPool', 'gremlinCount']) {
        if (entry[field] !== undefined) fail(`${p}.${field}`, 'is only supported by gremlin_gang');
      }
    }
    const fields = gremlin ? ['gremlinPool'] : louseCount ? ['lousePool'] : ['enemies', ...(entry.enemiesOnTrue === undefined ? [] : ['enemiesOnTrue'])];
    for (const field of fields) {
      const slots = [];
      array(entry[field], `${p}.${field}`).forEach((id, j) => {
        reference(id, 'enemies', `${p}.${field}[${j}]`);
        const enemy = lists.enemies.find(candidate => isObject(candidate) && candidate.id === id);
        slots.push(['spike_slime_l', 'acid_slime_l'].includes(enemy?.ai?.kind) ? 3 : 1);
        if (enemy && enemy.tier !== entry.tier) fail(`${p}.${field}[${j}]`, `enemy tier ${enemy.tier} does not match encounter tier ${entry.tier}`);
      });
      // The pool contains candidates, not eight simultaneous actors. Check the
      // largest legal four-slot draw, still including retained split parents.
      if (gremlin) slots.sort((a, b) => b - a);
      // Louse slots are sampled with replacement, so the largest candidate can
      // occupy every slot. The two-element pool is not a two-actor roster.
      const expandedSlots = louseCount ? Math.max(0, ...slots) * louseCount
        : (gremlin ? slots.slice(0, 4) : slots).reduce((sum, n) => sum + n, 0);
      if (expandedSlots > 5) fail(`${p}.${field}`, 'must fit five UI slots including retained split parents');
    }
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
    if (kind === 'potions') {
      enumeration(entry.targetPolicy, ['self', 'enemy_one', 'enemy_all', 'random_enemy'], `${p}.targetPolicy`);
      // Current effects operate on self or one enemy. Future group/random effects
      // need their own runtime implementation before entering the playable data.
      const single = Array.isArray(entry.effects) && entry.effects.some(effect => effect && ['damage', 'applyStatus'].includes(effect.op));
      const all = Array.isArray(entry.effects) && entry.effects.some(effect => effect && effect.op === 'damageAll');
      if (entry.targetPolicy !== (single ? 'enemy_one' : all ? 'enemy_all' : 'self')) fail(`${p}.targetPolicy`, 'must match implemented effect targets');
    }
    enumeration(entry.rarity, kind === 'relics' ? ['starter', 'common', 'uncommon', 'rare', 'boss', 'shop', 'special'] : ['common', 'uncommon', 'rare'], `${p}.rarity`);
    if (kind === 'relics') enumeration(entry.trigger, ['combat_start', 'turn_start', 'combat_end', 'shop', 'hooks'], `${p}.trigger`);
    if (entry.replaces !== undefined) reference(entry.replaces, 'relics', `${p}.replaces`);
    if (entry.blocksPotions !== undefined && typeof entry.blocksPotions !== 'boolean') fail(`${p}.blocksPotions`, 'must be boolean');
    if (entry.description !== undefined && typeof entry.description !== 'string') fail(`${p}.description`, 'must be text');
    if (entry.sourceId !== undefined && (typeof entry.sourceId !== 'string' || !entry.sourceId.length)) fail(`${p}.sourceId`, 'must be a nonempty source identity');
    if (entry.stackable !== undefined && (kind !== 'relics' || entry.id !== 'circlet' || entry.stackable !== true)) fail(`${p}.stackable`, 'only source Circlet supports repeated obtain counts');
    if (entry.scoreModifier !== undefined && (kind !== 'relics' || entry.id !== 'spirit_poop' || entry.scoreModifier !== -1)) fail(`${p}.scoreModifier`, 'must match source Spirit Poop penalty');
    if (entry.encounterTiers !== undefined) array(entry.encounterTiers, `${p}.encounterTiers`).forEach((tier, j) => enumeration(tier, tiers, `${p}.encounterTiers[${j}]`));
    if (kind === 'relics' && entry.trigger === 'hooks') {
      if (!['darkstone_periapt', 'omamori', 'ceramic_fish', 'potion_belt', 'meal_ticket', 'maw_bank', 'blood_vial', 'bag_of_marbles', 'orichalcum',
        'strawberry', 'regal_pillow', 'toy_ornithopter', 'whetstone', 'war_paint',
        'happy_flower', 'ancient_tea_set', 'art_of_war', 'boot', 'akabeko', 'pen_nib', 'nunchaku',
        'preserved_insect', 'red_skull', 'centennial_puzzle', 'tiny_chest', 'juzu_bracelet', 'dream_catcher',
        'warped_tongs', 'spirit_poop', 'circlet'].includes(entry.id)) fail(`${p}.id`, 'unsupported relic hook');
      if (!Array.isArray(entry.effects) || entry.effects.length !== 0) fail(`${p}.effects`, 'source hooks require empty generic effects');
    } else if (kind === 'relics' && entry.trigger === 'shop') {
      targetGroup(entry.effects, `${p}.effects`, false);
      if (!['membership_card', 'courier', 'smiling_mask'].includes(entry.id)) fail(`${p}.id`, 'unsupported shop relic');
      if (!Array.isArray(entry.effects) || entry.effects.length !== 0) fail(`${p}.effects`, 'shop relic uses merchant hooks and must have empty combat effects');
    } else effects(entry.effects, `${p}.effects`);
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
      if (rules.events.encounterId !== undefined) enumeration(rules.events.encounterId, ['cleric', 'purifier'], 'rules.events.encounterId');
      else enumeration(rules.events.poolMode, ['restricted-six', 'restricted-seven'], 'rules.events.poolMode');
      if (rules.events.poolMode !== undefined) {
        enumeration(rules.events.poolMode, ['restricted-six', 'restricted-seven'], 'rules.events.poolMode');
        const amounts = { goop: { damage: 11, gold: 75, lossMin: 20, lossMax: 50 },
          golden_wing: { damage: 7, goldMin: 50, goldMax: 80, attackThreshold: 10 },
          shining_light: { damagePercent: 20, upgradeCount: 2 } };
        for (const [id, fields] of Object.entries(amounts)) if (object(rules.events[id], `rules.events.${id}`)) {
          for (const [field, value] of Object.entries(fields)) integer(rules.events[id][field], `rules.events.${id}.${field}`, value, value);
        }
        if (rules.events.poolMode === 'restricted-seven') {
          if (object(rules.events.golden_shrine, 'rules.events.golden_shrine')) {
            integer(rules.events.golden_shrine.gold, 'rules.events.golden_shrine.gold', 100, 100);
            integer(rules.events.golden_shrine.curseGold, 'rules.events.golden_shrine.curseGold', 275, 275);
            enumeration(rules.events.golden_shrine.curse, ['regret'], 'rules.events.golden_shrine.curse');
            reference(rules.events.golden_shrine.curse, 'cards', 'rules.events.golden_shrine.curse');
          }
        }
      }
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
  if (bundle.relicSource !== undefined && object(bundle.relicSource, 'relicSource')) {
    const source = bundle.relicSource;
    if (source.schemaVersion !== 1 || source.sourceCommit !== '319009d5df0a82d9fb0f23cc22322286c6a87ec0') fail('relicSource', 'unknown source version');
    if (object(source.queues, 'relicSource.queues')) {
      const sizes = { common: 33, uncommon: 30, rare: 28, shop: 17, boss: 22 }, seen = new Set();
      for (const key of Object.keys(source.queues)) if (!(key in sizes)) fail(`relicSource.queues.${key}`, 'unknown tier');
      for (const [tier, size] of Object.entries(sizes)) {
        const list = source.queues[tier], path = `relicSource.queues.${tier}`;
        if (!Array.isArray(list) || list.length !== size) { fail(path, `requires complete ${size}-item source queue`); continue; }
        for (const id of list) {
          if (typeof id !== 'string' || !id || seen.has(id)) fail(path, 'invalid or duplicate source ID');
          seen.add(id);
        }
      }
    }
  }
  return errors;
}

export function loadContent(directory) {
  const bundle = {};
  for (const file of contentFiles) bundle[file] = JSON.parse(readFileSync(resolve(directory, `${file}.json`), 'utf8').replace(/^\uFEFF/, ''));
  const relicSource = resolve(directory, 'catalogs/sts1-relic-queues.json');
  if (existsSync(relicSource)) bundle.relicSource = JSON.parse(readFileSync(relicSource, 'utf8').replace(/^\uFEFF/, ''));
  return bundle;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const errors = validateContent(loadContent(process.argv[2] ?? 'data'));
    if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
    else console.log('Content validation passed (cards, statuses, enemies, encounters, relics, potions, rules).');
  } catch (error) { console.error(`Content validation failed: ${error.message}`); process.exitCode = 1; }
}
