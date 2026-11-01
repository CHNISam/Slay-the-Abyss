// Independent, small contract oracle for the pinned AbstractDungeon source.
// No production imports. This does not implement game relic effects or RNG.
export const tiers = ['common', 'uncommon', 'rare', 'shop', 'boss'];

export function javaShuffle(input, rawLongHex) {
  // Independent arithmetic check of the host Java vectors, using exact integers.
  const multiplier = 0x5deece66dn, mask = (1n << 48n) - 1n;
  let state = (BigInt(`0x${rawLongHex}`) ^ multiplier) & mask;
  const next31 = () => {
    state = (state * multiplier + 11n) & mask;
    return Number(state >> 17n);
  };
  const index = bound => {
    if ((bound & (bound - 1)) === 0) return Math.floor(bound * next31() / 2 ** 31);
    for (;;) {
      const bits = next31(), remainder = bits % bound;
      if (bits - remainder + bound - 1 < 2 ** 31) return remainder;
    }
  };
  const result = [...input];
  for (let size = result.length; size > 1; size--) {
    const j = index(size);
    [result[size - 1], result[j]] = [result[j], result[size - 1]];
  }
  return result;
}

export function rollTier(channel, roll) {
  if (!Number.isInteger(roll) || roll < 0 || roll > 99) throw new RangeError('roll must be 0..99');
  const thresholds = {
    elite: [50, 83], event: [50, 83], shovel: [50, 83],
    shop: [48, 82], 'small-chest': [75, 100],
    'medium-chest': [35, 85], 'large-chest': [0, 75],
  }[channel];
  if (!thresholds) throw new Error(`unknown channel ${channel}`);
  return roll < thresholds[0] ? 'common' : roll < thresholds[1] ? 'uncommon' : 'rare';
}

export function canSpawn(gate, context) {
  const {floor = 1, act = 1, room = 'monster', owned = [], deck = [], endless = false} = context;
  switch (gate.kind) {
    case 'always': return true;
    case 'max-floor': return (endless || floor <= gate.floor) && room !== gate.excludeRoom;
    case 'max-act': return act <= gate.act;
    case 'owns-relic': return owned.includes(gate.id);
    case 'card-type': return deck.some(card => card.type === gate.cardType);
    case 'nonbasic-card-type': return deck.some(card => card.type === gate.cardType && card.rarity !== 'BASIC');
    case 'campfire-limit': return (endless || floor < gate.maxExclusiveFloor) &&
      owned.filter(id => ['Peace Pipe', 'Shovel', 'Girya'].includes(id)).length < gate.maxCampfireRelics;
    default: throw new Error(`unknown spawn gate ${gate.kind}`);
  }
}

export function drawRelic(queues, tier, {end = false, eligible = () => true, reject = []} = {}) {
  const consumed = [];
  function take(requested, fromEnd, depth = 0) {
    if (depth > 1000) throw new Error('nonterminating eligibility predicate');
    const queue = queues[requested];
    if (!queue) throw new Error(`missing queue ${requested}`);
    let id;
    if (queue.length) id = (fromEnd && requested !== 'boss') ? queue.pop() : queue.shift();
    else if (requested === 'common' || requested === 'shop') return take('uncommon', false, depth + 1);
    else if (requested === 'uncommon') return take('rare', false, depth + 1);
    else id = requested === 'boss' ? 'Red Circlet' : 'Circlet';
    consumed.push({tier: requested, end: fromEnd, id});
    // A failed front candidate is spent; retry at the SAME tier's tail.
    if (!eligible(id)) return take(requested, true, depth + 1);
    return id;
  }
  let id;
  do { id = take(tier, end); } while (reject.includes(id));
  return {requestedId: id, resolvedId: id === 'Red Circlet' ? 'Circlet' : id, consumed};
}

export const screenlessReject = ['Bottled Flame', 'Bottled Lightning', 'Bottled Tornado', 'Whetstone'];
export const nonCampfireReject = ['Peace Pipe', 'Shovel', 'Girya'];
