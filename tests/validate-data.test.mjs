import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { contentFiles, validateContent } from '../scripts/validate-data.mjs';

function fixture() {
  const data = {
    cards: { starter_deck: { cards: ['strike', 'strike'] }, cards: [{ id: 'strike', name: '打击', type: 'attack', rarity: 'basic', cost: 1, effects: [{ op: 'damage', value: 6 }], upgrade: { cost: 0 } }] },
    statuses: { statuses: [{ id: 'strength', name: '力量', kind: 'buff', stack: 'intensity', decay: 'none' }] },
    enemies: { enemies: [{ id: 'slime', name: '史莱姆', tier: 'normal', hp: 12, intents: [{ id: 'attack', kind: 'attack', effects: [{ op: 'damage', value: 3 }] }] }], encounters: [{ id: 'slime_pair', tier: 'normal', enemies: ['slime', 'slime'], minFloor: 1, maxFloor: 14 }] },
    relics: { relics: [{ id: 'blood', name: '血', rarity: 'starter', trigger: 'combat_end', effects: [{ op: 'heal', value: 6 }] }] },
    potions: { potions: [{ id: 'strength', name: '力量药水', rarity: 'common', effects: [{ op: 'gainStatus', status: 'strength', value: 2 }] }] },
    rules: {
      version: '0.1.0',
      player: { maxHp: 80, energyPerTurn: 3, drawPerTurn: 5, maxHand: 10, startingGold: 99, startingRelics: ['blood'], potionSlots: 3 },
      map: { floors: 17, generatedRows: 15, bossFloor: 16, restFloor: 15, treasureFloor: 9, bossTreasureFloor: 17, nodeTypes: ['combat', 'elite', 'camp', 'shop', 'event', 'treasure', 'boss'] },
      camp: { healPercent: 30, upgradeCount: 1 },
      events: { encounterId: 'purifier', purifier: { removeCost: 0 }, cleric: { minGold: 35, healCost: 35, healPercent: 25, removeCost: 50 } },
      shop: { cardCommon: 50, cardUncommon: 75, cardRare: 150, relic: 150, removeCard: 75, removeCardIncrement: 25 },
      rewards: { normalGold: 15, eliteGold: 30, bossGold: 100, cardChoices: 3 },
      combat: { blockReset: 'owner_turn_start', vulnerablePercent: 150, weakPercent: 75, frailPercent: 75, rounding: 'floor_after_modifiers', enemyAI: 'intent_cycle', statusDurationTick: 'round_end', poisonBypassesBlock: true }
    }
  };
  for (const [tier, floor] of [['elite', 6], ['boss', 16]]) {
    data.enemies.enemies.push({ ...structuredClone(data.enemies.enemies[0]), id: `${tier}_slime`, tier });
    data.enemies.encounters.push({ id: `${tier}_encounter`, tier, enemies: [`${tier}_slime`], minFloor: floor, maxFloor: floor });
  }
  return data;
}

test('valid full bundle permits repeated starter cards and encounter enemies', () => {
  assert.deepEqual(validateContent(fixture()), []);
});

test('valid partial upgrades, signed strength and nested conditional references', () => {
  const data = fixture();
  data.cards.cards[0].upgrade = { effects: [{ op: 'applyStatus', status: 'strength', value: -3 }, { op: 'conditional', if: 'target_vulnerable', then: [{ op: 'addCardToDiscard', card: 'strike' }] }] };
  assert.deepEqual(validateContent(data), []);
});

const invalidCases = [
  ['missing cleric rules', d => delete d.rules.events, /rules.events/],
  ['unimplemented event identity', d => d.rules.events.encounterId = 'gold_or_potion', /rules.events.encounterId/],
  ['purifier must be free', d => d.rules.events.purifier.removeCost = 1, /rules.events.purifier.removeCost/],
  ['negative event removal cost', d => d.rules.events.cleric.removeCost = -1, /rules.events.cleric.removeCost/],
  ['invalid event healing percentage', d => d.rules.events.cleric.healPercent = 101, /rules.events.cleric.healPercent/],
  ['cleric eligibility below healing price', d => d.rules.events.cleric.minGold = 0, /rules.events.cleric.minGold/],
  ['missing content file', d => delete d.potions, /potions.json/],
  ['empty content list', d => d.cards.cards = [], /nonempty array/],
  ['malformed record', d => d.statuses.statuses[0] = null, /statuses\[0\].*object/],
  ['duplicate card ID', d => d.cards.cards.push(structuredClone(d.cards.cards[0])), /duplicate ID strike/],
  ['duplicate intent ID', d => d.enemies.enemies[0].intents.push(structuredClone(d.enemies.enemies[0].intents[0])), /duplicate ID attack/],
  ['invalid ID syntax', d => d.cards.cards[0].id = 'Bad ID', /snake_case/],
  ['missing card reference', d => d.cards.starter_deck.cards = ['missing'], /unknown cards ID/],
  ['missing enemy reference', d => d.enemies.encounters[0].enemies = ['missing'], /unknown enemies ID/],
  ['missing status reference', d => d.potions.potions[0].effects[0].status = 'missing', /unknown statuses ID/],
  ['nested missing reference', d => d.cards.cards[0].effects = [{ op: 'conditional', if: 'target_vulnerable', then: [{ op: 'addCardToDiscard', card: 'missing' }] }], /then\[0\].card.*unknown/],
  ['unknown operation', d => d.cards.cards[0].effects[0].op = 'damgae', /\.op: must be one of/],
  ['unknown card type', d => d.cards.cards[0].type = 'spell', /\.type:/],
  ['unknown enemy tier', d => d.enemies.enemies[0].tier = 'legendary', /\.tier:/],
  ['unknown rarity', d => d.relics.relics[0].rarity = 'legendary', /\.rarity:/],
  ['unknown trigger', d => d.relics.relics[0].trigger = 'never', /\.trigger:/],
  ['unknown status enum', d => d.statuses.statuses[0].decay = 'maybe', /\.decay:/],
  ['unknown condition', d => d.cards.cards[0].condition = 'no_other_attack_in_hand', /\.condition:/],
  ['negative damage', d => d.cards.cards[0].effects[0].value = -1, /\.value:/],
  ['fractional cost', d => d.cards.cards[0].cost = 0.5, /\.cost:/],
  ['excessive cost', d => d.cards.cards[0].cost = 6, /\.cost:/],
  ['non numeric cost', d => d.cards.cards[0].cost = '1', /\.cost:/],
  ['zero hit count', d => d.cards.cards[0].effects[0].times = 0, /\.times:/],
  ['zero enemy hp', d => d.enemies.enemies[0].hp = 0, /\.hp:/],
  ['unsafe integer', d => d.enemies.enemies[0].hp = Number.MAX_SAFE_INTEGER + 1, /\.hp:/],
  ['floor outside combat rooms', d => d.enemies.encounters[0].maxFloor = 17, /\.maxFloor:/],
  ['reversed floor range', d => d.enemies.encounters[0].minFloor = 15, /minFloor must not exceed/],
  ['invalid upgrade cost', d => d.cards.cards[0].upgrade = { cost: -1 }, /upgrade.cost:/],
  ['empty upgrade', d => d.cards.cards[0].upgrade = {}, /must change/],
  ['misspelled upgrade field', d => d.cards.cards[0].upgrade = { costt: 0 }, /upgrade.costt: unknown field/],
  ['misspelled effect field', d => d.cards.cards[0].effects[0].vale = 10, /vale: unknown field/],
  ['mismatched enemy tier', d => d.enemies.enemies[0].tier = 'boss', /does not match encounter tier/],
  ['missing rules file', d => delete d.rules, /rules.json/],
  ['missing rules section', d => delete d.rules.player, /rules.player:.*object/],
  ['invalid max hp', d => d.rules.player.maxHp = 0, /rules.player.maxHp/],
  ['invalid turn energy', d => d.rules.player.energyPerTurn = -1, /rules.player.energyPerTurn/],
  ['missing starting relic', d => d.rules.player.startingRelics = ['missing'], /unknown relics ID/],
  ['wrong map floor count', d => d.rules.map.floors = 2, /rules.map.floors/],
  ['wrong boss floor', d => d.rules.map.bossFloor = 14, /rules.map.bossFloor/],
  ['missing node type', d => d.rules.map.nodeTypes.pop(), /all seven node types/],
  ['repeated node type', d => d.rules.map.nodeTypes[0] = 'boss', /all seven node types/],
  ['invalid shop price', d => d.rules.shop.removeCard = -1, /rules.shop.removeCard/],
  ['invalid camp heal', d => d.rules.camp.healPercent = 101, /rules.camp.healPercent/],
  ['invalid rule enum', d => d.rules.combat.rounding = 'ceil', /rules.combat.rounding/],
  ['invalid rule boolean', d => d.rules.combat.poisonBypassesBlock = 'true', /rules.combat.poisonBypassesBlock/],
  ['nonboolean exhaust', d => d.cards.cards[0].exhaust = 'true', /\.exhaust:/]
];
for (const [name, mutate, expected] of invalidCases) {
  test(`rejects ${name}`, () => {
    const data = fixture();
    mutate(data);
    const errors = validateContent(data);
    assert.ok(errors.length > 0);
    assert.match(errors.join('\n'), expected);
  });
}

test('CLI exits nonzero for missing files, invalid JSON and invalid content; succeeds for full valid files', () => {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-content-'));
  const run = () => spawnSync(process.execPath, [resolve('scripts/validate-data.mjs'), directory], { encoding: 'utf8', timeout: 10000 });
  try {
    const missing = run();
    assert.equal(missing.status, 1);
    assert.match(missing.stderr, /Content validation failed/);
    const data = fixture();
    for (const file of contentFiles) writeFileSync(join(directory, `${file}.json`), JSON.stringify(data[file]));
    assert.equal(run().status, 0);
    writeFileSync(join(directory, 'cards.json'), '{"op":"exhaust":true}');
    assert.equal(run().status, 1);
    data.cards.cards[0].cost = -1;
    writeFileSync(join(directory, 'cards.json'), JSON.stringify(data.cards));
    const invalid = run();
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /cards\[0\].cost/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
