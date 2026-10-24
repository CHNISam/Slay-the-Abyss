import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const large = data => data.enemies.enemies.find(enemy => enemy.id === 'acid_slime_l');
function setup() {
  const data = loadContent('data'), enemy = large(data);
  Object.assign(enemy.ai, {splitIntent: 'acid_slime_l_split', splitEnemy: 'acid_slime_m', splitCount: 2, splitHpDivisor: 2});
  if (!enemy.intents.some(intent => intent.id === enemy.ai.splitIntent)) {
    enemy.intents.push({id: enemy.ai.splitIntent, kind: 'split', effects: []});
  }
  return data;
}
test('existing Large Acid encounter declares source split into two real medium children', () => {
  const data = loadContent('data'), enemy = large(data);
  assert.equal(enemy.ai.splitEnemy, 'acid_slime_m');
  assert.equal(enemy.ai.splitCount, 2);
  assert.equal(enemy.ai.splitHpDivisor, 2);
  assert.equal(enemy.intents.find(intent => intent.id === enemy.ai.splitIntent)?.kind, 'split');
  assert.deepEqual(validateContent(data), []);
});
test('source Acid split policy is accepted', () => assert.deepEqual(validateContent(setup()), []));
for (const [field, value] of [
  ['splitIntent', undefined], ['splitIntent', 'acid_slime_l_1'], ['splitIntent', 'missing'],
  ['splitEnemy', 'missing'], ['splitEnemy', 'acid_slime_l'], ['splitEnemy', 'spike_slime_m'],
  ['splitCount', 1], ['splitCount', 3], ['splitCount', 2.5], ['splitHpDivisor', 1], ['splitHpDivisor', 3],
]) test(`reject Acid split ${field} ${value}`, () => {
  const data = setup();
  large(data).ai[field] = value;
  if (value === undefined) delete large(data).ai[field];
  assert.ok(validateContent(data).some(error => error.includes(field)));
});
test('Acid split child must retain the supported Medium Acid policy', () => {
  const data = setup();
  delete data.enemies.enemies.find(enemy => enemy.id === 'acid_slime_m').ai;
  assert.ok(validateContent(data).some(error => error.includes('splitEnemy')));
});
test('Acid split has no damage or status payload', () => {
  const data = setup();large(data).intents.at(-1).effects = [{op: 'damage', value: 99}];
  assert.ok(validateContent(data).some(error => error.includes('effects')));
});
for (const id of ['acid_slime_m', 'acid_slime_s']) test(`${id} cannot split recursively`, () => {
  const data = setup(), enemy = data.enemies.enemies.find(entry => entry.id === id);
  Object.assign(enemy.ai, {splitIntent: 'invented_split', splitEnemy: 'acid_slime_m', splitCount: 2, splitHpDivisor: 2});
  enemy.intents.push({id: 'invented_split', kind: 'split', effects: []});
  assert.ok(validateContent(data).some(error => error.includes('matching AI')));
});
for (const other of ['acid_slime_l', 'spike_slime_l']) test(`two large slimes overflow retained-parent capacity: ${other}`, () => {
  const data = setup();
  data.enemies.encounters.find(encounter => encounter.id === 'large_acid').enemies = ['acid_slime_l', other];
  assert.ok(validateContent(data).some(error => error.includes('five')));
});
test('one Large Acid with two existing allies fits exactly five retained slots', () => {
  const data = setup();
  data.enemies.encounters.find(encounter => encounter.id === 'large_acid').enemies = ['sneaky_gremlin', 'acid_slime_l', 'acid_slime_m'];
  assert.deepEqual(validateContent(data), []);
});
