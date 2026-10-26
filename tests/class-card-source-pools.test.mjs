import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(path, 'utf8');
const registration = JSON.parse(read('data/reference/sts1-card-pools/registration.json')).registration;
const order = JSON.parse(read('data/reference/sts1-card-pools/pools.json')).pools.libraryHashMapTraversal;
const byId = new Map(registration.map(row => [row.id, row]));
const source = read('src/lua/abyss_class_card_pools.lua');
for (const [character, color] of [['silent', 'GREEN'], ['defect', 'BLUE'], ['watcher', 'PURPLE']]) {
  test(`${character} full pool identities/order/types/tags match the pinned independent catalog`, () => {
    const block = source.match(new RegExp(`    ${character}=\\{([\\s\\S]*?)\\n    \\},`))[1];
    const actual = [...block.matchAll(/\{([^{}]+)\},/g)].map(match => JSON.parse(`[${match[1]}]`));
    const expected = order.map(id => byId.get(id)).filter(row => row.color === color
      && ['COMMON', 'UNCOMMON', 'RARE'].includes(row.rarity));
    assert.equal(actual.length, 71);
    assert.equal(new Set(actual.map(row => row[0])).size, 71);
    assert.deepEqual(actual.map(row => row.slice(1)), expected.map(row => [row.id, row.class,
      row.rarity.toLowerCase(), row.type.toLowerCase(), row.tags.includes('HEALING')]));
  });
}
