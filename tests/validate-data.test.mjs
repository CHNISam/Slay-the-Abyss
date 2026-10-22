import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { contentFiles, validateContent } from '../scripts/validate-data.mjs';

function fixture() {
  return {
    cards: { starter_deck: { cards: ['strike', 'strike'] }, cards: [{ id: 'strike', name: '打击', type: 'attack', rarity: 'basic', cost: 1, effects: [{ op: 'damage', value: 6 }], upgrade: { cost: 0 } }] },
    statuses: { statuses: [{ id: 'strength', name: '力量', kind: 'buff', stack: 'intensity', decay: 'none' }] },
    enemies: { enemies: [{ id: 'slime', name: '史莱姆', tier: 'normal', hp: 12, intents: [{ id: 'attack', kind: 'attack', effects: [{ op: 'damage', value: 3 }] }] }], encounters: [{ id: 'slime_pair', tier: 'normal', enemies: ['slime', 'slime'], minFloor: 1, maxFloor: 14 }] },
    relics: { relics: [{ id: 'blood', name: '血', rarity: 'starter', trigger: 'combat_end', effects: [{ op: 'heal', value: 6 }] }] },
    potions: { potions: [{ id: 'strength', name: '力量药水', rarity: 'common', effects: [{ op: 'gainStatus', status: 'strength', value: 2 }] }] }
  };
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
  ['floor outside first act', d => d.enemies.encounters[0].maxFloor = 16, /\.maxFloor:/],
  ['reversed floor range', d => d.enemies.encounters[0].minFloor = 15, /minFloor must not exceed/],
  ['invalid upgrade cost', d => d.cards.cards[0].upgrade = { cost: -1 }, /upgrade.cost:/],
  ['empty upgrade', d => d.cards.cards[0].upgrade = {}, /must change/],
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
