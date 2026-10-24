import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

const enemy = data => data.enemies.enemies.find(entry => entry.id === 'acid_slime_l');
const policy = {
  kind: 'acid_slime_l', spitIntent: 'acid_slime_l_1', weakIntent: 'acid_slime_l_2',
  tackleIntent: 'acid_slime_l_3', rollRange: 100, spitCutoff: 30, tackleCutoff: 70,
  spitChance: 0.4000000059604645,
};
const payloads = [
  [{ op: 'damage', value: 11 }, { op: 'makeTempCardInDiscard', card: 'slimed', value: 2 }],
  [{ op: 'applyStatus', status: 'weak', value: 2 }],
  [{ op: 'damage', value: 16 }],
];
function setup() {
  const data = loadContent('data');
  const entry = enemy(data);
  entry.ai = { ...policy };
  entry.hpRange = { min: 65, max: 69 };
  entry.intents = payloads.map((effects, index) => ({
    id: `acid_slime_l_${index + 1}`, kind: index === 1 ? 'debuff' : 'attack',
    effects: structuredClone(effects),
  }));
  return data;
}

test('Large Acid carries the source non-split actions, HP range and exact float fallback', () => {
  const data = loadContent('data'), entry = enemy(data);
  assert.deepEqual(entry.ai, policy);
  assert.deepEqual(entry.hpRange, { min: 65, max: 69 });
  assert.deepEqual(entry.intents.map(intent => intent.effects), payloads);
  assert.deepEqual(validateContent(data), []);
});
test('strict Large Acid non-split policy is accepted', () => assert.deepEqual(validateContent(setup()), []));

for (const [field, value] of [
  ['kind', 'guessed_acid'], ['spitIntent', undefined], ['weakIntent', undefined], ['tackleIntent', undefined],
  ['spitIntent', 'acid_slime_l_2'], ['weakIntent', 'acid_slime_l_1'], ['tackleIntent', 'acid_slime_l_1'],
  ['tackleIntent', 'missing'], ['rollRange', 0], ['rollRange', 65537], ['rollRange', 1.5],
  ['spitCutoff', -1], ['spitCutoff', 70], ['tackleCutoff', 100], ['tackleCutoff', 1.5],
  ['spitChance', undefined], ['spitChance', -0.1], ['spitChance', 1.1], ['spitChance', '0.4'],
  ['spitChance', NaN], ['spitChance', Infinity], ['guess', 1],
]) test(`Large Acid policy rejects ${field} ${value}`, () => {
  const data = setup();
  enemy(data).ai[field] = value;
  if (value === undefined) delete enemy(data).ai[field];
  assert.ok(validateContent(data).some(error => error.includes(field)));
});

for (const [label, change] of [
  ['missing contamination', effects => effects.pop()],
  ['reversed order', effects => effects.reverse()],
  ['wrong card', effects => effects[1].card = 'dazed'],
  ['medium count', effects => effects[1].value = 1],
  ['extra count', effects => effects[1].value = 3],
  ['extra effect', effects => effects.push({ ...effects[1] })],
]) test(`Large Acid corrosive attack rejects ${label}`, () => {
  const data = setup();
  change(enemy(data).intents[0].effects);
  assert.ok(validateContent(data).some(error => error.includes('spitIntent')));
});

test('Large Acid schema does not relax the established Medium Acid one-Slimed contract', () => {
  const data = setup();
  const medium = data.enemies.enemies.find(entry => entry.id === 'acid_slime_m');
  medium.intents[0].effects[1].value = 2;
  const index = data.enemies.enemies.indexOf(medium);
  assert.ok(validateContent(data).some(error => error.startsWith(`enemies[${index}].ai.spitIntent:`)));
});
