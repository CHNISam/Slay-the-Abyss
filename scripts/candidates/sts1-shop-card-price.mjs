/**
 * Candidate arithmetic only. Not imported by the Lua game or content builders.
 * Evidence and unresolved target-build provenance:
 * docs/reviews/TASK-13.1-shop-card-price-evidence.md
 * No random generator, inventory selection, state, or runtime parity claim.
 */
const f32 = Math.fround;
const bases = new Map([['common', 50], ['uncommon', 75], ['rare', 150]]);
const fields = new Set(['rarity', 'multiplier', 'phase', 'color', 'sale', 'courier', 'membership']);
const multiply = (left, right) => f32(f32(left) * f32(right));
const roundPositive = value => Math.floor(value + 0.5);

/** Conditional on the documented libGDX 24-bit grid, not a seed/RNG API. */
export function multiplierFromUint24(sample) {
  if (!Number.isInteger(sample) || sample < 0 || sample >= 2 ** 24) {
    throw new RangeError('Invalid uint24 sample');
  }
  const unit = sample / 2 ** 24;
  return f32(f32(0.9) + multiply(unit, f32(f32(1.1) - f32(0.9))));
}

/**
 * A0 card quote with an injected merchant multiplier, normalized to binary32.
 * Initial: truncate, optional colored sale, Courier round, Membership round.
 * Restock: Courier required; no sale; truncate after all float products.
 * Only normal shop rarity/color combinations are accepted.
 */
export function quoteCard(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new TypeError('Invalid quote options');
  }
  for (const key of Object.keys(options)) {
    if (!fields.has(key)) throw new TypeError(`Unsupported quote option: ${key}`);
  }
  const { rarity, multiplier, phase = 'initial', color = 'colored', sale = false,
    courier = false, membership = false } = options;
  if (!bases.has(rarity)) throw new RangeError('Unsupported rarity');
  if (!['initial', 'restock'].includes(phase)) throw new RangeError('Unsupported phase');
  if (!['colored', 'colorless'].includes(color)) throw new RangeError('Unsupported color');
  if ([sale, courier, membership].some(value => typeof value !== 'boolean')) {
    throw new TypeError('Invalid discount flag');
  }
  if (color === 'colorless' && (rarity === 'common' || sale)) {
    throw new RangeError('Unsupported colorless rarity or sale');
  }
  if (phase === 'restock' && (!courier || sale)) {
    throw new RangeError('Unsupported restock without Courier or with sale');
  }
  if (typeof multiplier !== 'number' || !Number.isFinite(multiplier)
      || multiplier < f32(0.9) || multiplier > f32(1.1)) {
    throw new RangeError('Invalid merchant multiplier');
  }
  let price = multiply(bases.get(rarity), multiplier);
  if (color === 'colorless') price = multiply(price, 1.2);
  if (phase === 'restock') {
    price = multiply(price, 0.8);
    if (membership) price = multiply(price, 0.5);
    return Math.trunc(price);
  }
  price = Math.trunc(price);
  if (sale) price = Math.trunc(price / 2);
  if (courier) price = roundPositive(multiply(price, 0.8));
  if (membership) price = roundPositive(multiply(price, 0.5));
  return price;
}

/** Membership acquired in-store: existing A0 card shelf quote, no reroll.
 * Domain 0..198 is intentionally limited to the candidate's supported prices.
 */
export function discountExistingPrice(price) {
  if (!Number.isInteger(price) || price < 0 || price > 198) {
    throw new RangeError('Invalid existing card price (expected integer 0..198)');
  }
  return roundPositive(multiply(price, 0.5));
}
