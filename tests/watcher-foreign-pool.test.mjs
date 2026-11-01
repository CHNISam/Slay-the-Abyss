import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync('src/lua/abyss_watcher_foreign_pool.lua', 'utf8');
const registration = JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json', 'utf8')).registration;
for (const [rarity, count] of [['common', 43], ['uncommon', 48], ['rare', 15]]) {
  test(`Foreign Influence preserves every pinned ${rarity} non-HEALING attack`, () => {
    const block = source.match(new RegExp(`M\\.${rarity}=\\{([\\s\\S]*?)\\n\\}`))[1];
    const actual = [...block.matchAll(/"([^"]+)"/g)].map(match => match[1]);
    const expected = registration.filter(row => row.rarity === rarity.toUpperCase()
      && row.type === 'ATTACK' && !row.tags.includes('HEALING')).map(row => row.id).sort();
    assert.equal(actual.length, count);
    assert.equal(new Set(actual).size, count);
    assert.deepEqual(actual, expected);
  });
}
