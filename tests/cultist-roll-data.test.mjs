import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const cultist = data => data.enemies.enemies.find(enemy => enemy.id === 'cultist');

test('Cultist primary roll range enters the validated runtime catalog', () => {
  const data = loadContent('data');
  assert.equal(cultist(data).ai.rollRange, 100);
  assert.deepEqual(validateContent(data), []);
});
for (const [name, value] of [
  ['missing', undefined], ['zero', 0], ['negative', -1],
  ['fractional', 99.5], ['too large', 65537], ['string', '100'],
]) test(`Cultist rejects ${name} primary roll range`, () => {
  const data = loadContent('data');
  if (value === undefined) delete cultist(data).ai.rollRange;
  else cultist(data).ai.rollRange = value;
  assert.ok(validateContent(data).some(error => error.includes('rollRange')));
});

test('Cultist valid roll range is not rejected as an unknown AI field', () => {
  const data = loadContent('data');
  cultist(data).ai.rollRange = 100;
  assert.deepEqual(validateContent(data), []);
});
