import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { contentFiles, loadContent, validateContent } from '../scripts/validate-data.mjs';

const forced = [[1, 'normal'], [6, 'elite'], [15, 'boss']];
const fixture = () => loadContent('data');
const diagnostic = (floor, tier) => new RegExp(`enemies\\.encounters:.*${tier}.*floor ${floor}\\b`);

test('real content satisfies the existing map contract', () => {
  assert.deepEqual(validateContent(fixture()), []);
});

for (const restFloor of [0, 1, 13, 15, 16, 14.5, '14', null]) {
  test(`rejects restFloor ${JSON.stringify(restFloor)} instead of the required floor 14`, () => {
    const data = fixture();
    data.rules.map.restFloor = restFloor;
    assert.match(validateContent(data).join('\n'), /rules\.map\.restFloor:/);
  });
}

for (const [floor, tier] of forced) {
  test(`rejects missing ${tier} pool at forced floor ${floor}`, () => {
    const data = fixture();
    data.enemies.encounters = data.enemies.encounters.filter(entry => entry.tier !== tier);
    assert.match(validateContent(data).join('\n'), diagnostic(floor, tier));
  });

  for (const side of ['before', 'after']) {
    // Stay inside the existing 1..15 schema, isolating coverage from range validation.
    if ((side === 'before' && floor === 1) || (side === 'after' && floor === 15)) continue;
    test(`rejects ${tier} ranges entirely ${side} forced floor ${floor}`, () => {
      const data = fixture();
      for (const entry of data.enemies.encounters.filter(entry => entry.tier === tier)) {
        entry.minFloor = side === 'before' ? 1 : floor + 1;
        entry.maxFloor = side === 'before' ? floor - 1 : 15;
      }
      assert.match(validateContent(data).join('\n'), diagnostic(floor, tier));
    });
  }

  for (const [boundary, minFloor, maxFloor] of [['exact', floor, floor], ['max', 1, floor], ['min', floor, 15]]) {
    test(`accepts ${tier} ${boundary} boundary ${minFloor}..${maxFloor} at forced floor ${floor}`, () => {
      const data = fixture();
      const candidate = data.enemies.encounters.find(entry => entry.tier === tier);
      data.enemies.encounters = data.enemies.encounters.filter(entry => entry.tier !== tier || entry === candidate);
      Object.assign(candidate, { minFloor, maxFloor });
      assert.deepEqual(validateContent(data), []);
    });
  }
}

test('only forced combat floors need coverage, with one candidate each and repeated enemy references allowed', () => {
  const data = fixture();
  data.enemies.encounters = forced.map(([floor, tier]) => {
    const entry = data.enemies.encounters.find(candidate => candidate.tier === tier);
    return { ...entry, minFloor: floor, maxFloor: floor, enemies: [entry.enemies[0], entry.enemies[0]] };
  });
  assert.deepEqual(validateContent(data), []);
});

test('additional valid candidates and reversed input order do not invalidate map coverage', () => {
  const data = fixture();
  const entry = data.enemies.encounters.find(candidate => candidate.tier === 'elite');
  data.enemies.encounters.push({ ...entry, id: 'extra_elite', minFloor: 7, maxFloor: 13 });
  data.enemies.encounters.reverse();
  assert.deepEqual(validateContent(data), []);
});

test('malformed encounter entries report validation errors rather than throwing', () => {
  const data = fixture();
  data.enemies.encounters = [null, {}, false];
  const errors = validateContent(data).join('\n');
  for (const [floor, tier] of forced) assert.match(errors, diagnostic(floor, tier));
});

test('CLI rejects each broken forced-floor contract and accepts real content', () => {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-map-contract-'));
  const run = data => {
    for (const file of contentFiles) writeFileSync(join(directory, `${file}.json`), JSON.stringify(data[file]));
    return spawnSync(process.execPath, [resolve('scripts/validate-data.mjs'), directory], { encoding: 'utf8', timeout: 10000 });
  };
  try {
    const valid = run(fixture());
    assert.equal(valid.status, 0, valid.stderr);
    const badRest = fixture();
    badRest.rules.map.restFloor = 13;
    const restResult = run(badRest);
    assert.equal(restResult.status, 1);
    assert.match(restResult.stderr, /rules\.map\.restFloor:/);
    for (const [floor, tier] of forced) {
      const data = fixture();
      data.enemies.encounters = data.enemies.encounters.filter(entry => entry.tier !== tier);
      const result = run(data);
      assert.equal(result.status, 1);
      assert.match(result.stderr, diagnostic(floor, tier));
    }
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
