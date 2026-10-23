import test from 'node:test';
import assert from 'node:assert/strict';
import { quoteCard, multiplierFromUint24, discountExistingPrice } from '../scripts/candidates/sts1-shop-card-price.mjs';

// Literal expectations from PR61 arithmetic evidence, NOT target-game observations.
for (const [sample, colored, colorless] of [
  [0, [45, 67, 135], [81, 162]],
  [8388608, [50, 75, 150], [90, 180]],
  [16777215, [55, 82, 165], [99, 198]],
]) {
  for (const [i, rarity] of ['common', 'uncommon', 'rare'].entries()) {
    test(`initial ${rarity} uint24=${sample}`, () => {
      assert.equal(quoteCard({ rarity, multiplier: multiplierFromUint24(sample) }), colored[i]);
    });
  }
  for (const [i, rarity] of ['uncommon', 'rare'].entries()) {
    test(`initial colorless ${rarity} uint24=${sample}`, () => {
      assert.equal(quoteCard({ rarity, color: 'colorless', multiplier: multiplierFromUint24(sample) }), colorless[i]);
    });
  }
}

for (const [label, options, expected] of [
  ['sale truncates odd price', { sale: true }, 25],
  ['membership rounds half up', { membership: true }, 26],
  ['courier then membership rounds twice', { courier: true, membership: true }, 21],
  ['restock truncates only at end', { phase: 'restock', courier: true, membership: true }, 20],
  ['sale before both discounts', { sale: true, courier: true, membership: true }, 10],
  ['Smiling Mask has no card-price input', {}, 51],
]) {
  test(label, () => assert.equal(quoteCard({ rarity: 'common', multiplier: Math.fround(1.02), ...options }), expected));
}

test('membership purchase discounts the existing integer, without RNG', () => {
  assert.equal(discountExistingPrice(51), 26);
  assert.equal(discountExistingPrice(0), 0);
  assert.equal(discountExistingPrice(198), 99);
});
test('restock keeps the fractional base until the final truncation', () => {
  // 75 * 0.9F rounds to 67.5F; then * 0.8F = 54F.
  // Incorrect early truncation would yield floor(67 * 0.8F) = 53.
  assert.equal(quoteCard({ rarity: 'uncommon', multiplier: multiplierFromUint24(0),
    phase: 'restock', courier: true }), 54);
});
test('binary32 upper endpoint is reachable, despite u < 1', () => {
  assert.equal(multiplierFromUint24(16777215), Math.fround(1.1));
  assert.equal(multiplierFromUint24(0), Math.fround(0.9));
  assert.equal(multiplierFromUint24(8388608), 1);
});
test('uint24 interval mapping rounds each float operation, not just the result', () => {
  assert.equal(multiplierFromUint24(1), 0.8999999761581421);
});
test('injected multiplier is normalized before multiplication', () => {
  assert.equal(quoteCard({ rarity: 'rare', multiplier: 0.9266666 }), 139);
});
test('arguments are immutable and calls deterministic', () => {
  const options = Object.freeze({ rarity: 'rare', color: 'colorless', multiplier: 1, courier: true });
  assert.equal(quoteCard(options), 144);
  assert.equal(quoteCard(options), 144);
});
for (const sample of [-1, 16777216, 0.5, NaN, Infinity, '1', null]) {
  test(`reject invalid uint24 ${String(sample)}`, () => assert.throws(() => multiplierFromUint24(sample), /uint24/));
}
for (const patch of [
  { rarity: 'basic' }, { rarity: 'special' }, { rarity: 'toString' }, { rarity: null },
  { multiplier: NaN }, { multiplier: Infinity }, { multiplier: 0.89 }, { multiplier: 1.11 },
  { multiplier: '1' }, { color: 'unknown' }, { color: 'colorless', rarity: 'common' },
  { phase: 'unknown' }, { phase: 'restock' }, { phase: 'restock', courier: true, sale: true },
  { color: 'colorless', rarity: 'rare', sale: true }, { sale: 1 }, { courier: 'true' },
  { membership: null }, { ascension: 16 }, { smilingMask: true },
]) {
  test(`reject unsupported quote ${JSON.stringify(patch)}`, () => {
    assert.throws(() => quoteCard({ rarity: 'common', multiplier: 1, ...patch }), /Invalid|Unsupported/);
  });
}
test('reject malformed quote objects', () => {
  for (const value of [null, undefined, [], 'common', 1]) assert.throws(() => quoteCard(value), /Invalid/);
});
for (const value of [-1, 1.5, NaN, Infinity, '51', 199, null]) {
  test(`reject existing price outside supported shelf domain ${String(value)}`, () => {
    assert.throws(() => discountExistingPrice(value), /price/);
  });
}
