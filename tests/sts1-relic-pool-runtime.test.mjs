import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { javaShuffle, tiers, drawRelic, screenlessReject } from '../tools/oracles/sts1_relic_queues.mjs';

const read = path => JSON.parse(readFileSync(path, 'utf8'));
const vectors = read('tests/fixtures/sts1-relic-pool-vectors.json');
const facts = read('docs/rules/evidence/sts1-relic-pool-catalog.json');

test('production Lua selector matches all 12 host-Java queue vectors and independent JS shuffle', () => {
  const catalog = read('data/catalogs/sts1-relic-queues.json');
  assert.deepEqual(catalog.queues, vectors.unshuffled);
  assert.deepEqual(catalog.spawnGates, Object.fromEntries(facts.relics.filter(r => tiers.includes(r.tier)).map(r => [r.id, r.spawnGate])));
  for (const sample of vectors.cases) for (const [i, tier] of tiers.entries()) {
    assert.deepEqual(sample.queues[tier], javaShuffle(catalog.queues[tier].filter(id => !sample.locked.includes(id)), sample.randomLongHex[i]).filter(id => !sample.removedAfterShuffle.includes(id)));
  }
  const dir = mkdtempSync(join(tmpdir(), 'abyss-relic-pool-'));
  try {
    const file = join(dir, 'runtime.lua');
    const tracks = [false, true].map(fromTail => {
      const sample = vectors.cases[0], queues = structuredClone(sample.queues), steps = [];
      // Shared queues are consumed across channels, including past exhaustion.
      // Deterministic source eligibility deliberately rejects both front/tail
      // candidates; screenless separately consumes its forbidden source IDs.
      const refused = ['MealTicket', 'Bottled Tornado', 'Black Blood'];
      for (let i = 0; i < 180; i++) {
        const tier = tiers[i % tiers.length], screenless = i % 3 === 0;
        const result = drawRelic(queues, tier, { end: screenless ? false : fromTail,
          eligible: id => !refused.includes(id), reject: screenless ? screenlessReject : [] });
        steps.push({ tier, screenless, fromTail, result, queues: structuredClone(queues) });
      }
      return { seed: sample.seed, refused, steps };
    });
    writeFileSync(file, `ABYSS_RELIC_FIXTURE=${toLua({ catalog, cases: vectors.cases, tracks })}\ndofile('tests/lua/relic_pool.lua')\n`);
    const result = runLua(file);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /LUA_RELIC_POOL_PASS/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
