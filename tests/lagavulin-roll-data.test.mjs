import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const lagavulin = data => data.enemies.enemies.find(enemy => enemy.id === 'lagavulin');

test('Lagavulin primary roll range enters the validated runtime catalog', () => {
  const data = loadContent('data');
  assert.equal(lagavulin(data).ai.rollRange, 100);
  assert.deepEqual(validateContent(data), []);
});
for (const [name, value] of [
  ['missing', undefined], ['zero', 0], ['negative', -1],
  ['fractional', 99.5], ['too large', 65537], ['string', '100'],
]) test(`Lagavulin rejects ${name} primary roll range`, () => {
  const data = loadContent('data');
  if (value === undefined) delete lagavulin(data).ai.rollRange;
  else lagavulin(data).ai.rollRange = value;
  assert.ok(validateContent(data).some(error => error.includes('rollRange')));
});

test('Lagavulin valid roll range is not rejected as an unknown AI field', () => {
  const data = loadContent('data');
  lagavulin(data).ai.rollRange = 100;
  assert.deepEqual(validateContent(data), []);
});
