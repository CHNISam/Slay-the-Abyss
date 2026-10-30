import test from 'node:test';
import {readHistoricalBaselineSource} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const entry = 'tests/lua/card_help_release.lua';
// The full original-body proof is historical; wrappers, discovery and budgets remain current.
const originalSource = () => readHistoricalBaselineSource(entry).replaceAll('\r\n', '\n');
// Full original LF source at b420e8b267bbdbf2d5d7c68bc7d893faa130047c,
// unchanged from develop d16be8db. Includes helpers, every case body and loop.
const original = {
  bytes: 11056,
  sha256: '088862441fab127f5f29dee6cc990ab39b59152e57250310386bae6b8f3808f2',
  blob: '30be7f602416c592771604abcc4a80ba30ae8386',
};
// Keep PR262's finer eight ranges rather than reintroducing PR263's two
// larger executable ranges on top of them. Both retain this same full body.
const prefix = "local first,last=...\nfirst,last=first or 1,last or 4\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=31 and first<=last,'invalid UI budget slice')\nlocal registered=0\n";
const before = 'local function test(name, fn)\n';
const after = before + "    registered=registered+1\n    if registered<first or registered>last then return end\n";
const footer = "assert(registered==31,'original UI case discovery changed')\nassert(passed+failed==last-first+1,'UI budget slice coverage changed')\n";
const summary = "print('LUA_CARD_HELP_RELEASE ' .. passed .. ' passed; ' .. failed .. ' failed')\nassert(failed == 0, 'card-help ownership regressions failed')\n";
const ranges = Array.from({ length: 8 }, (_, i) => [
  i === 0 ? entry : `tests/lua/card_help_release_slice_${i + 1}.lua`, i * 4 + 1, Math.min((i + 1) * 4, 31),
]);
const wrappers = () => Object.fromEntries(ranges.slice(1).map(([path]) => [path, read(path)]));

function validateSource(source) {
  assert.ok(source.startsWith(prefix), 'only the reviewed original-budget range prefix');
  assert.ok(source.endsWith(footer + summary), 'registration and execution counts must remain enforced');
  let restored = source.slice(prefix.length).replace(footer, '');
  assert.equal(restored.split(after).length, 2, 'one exact range-registration harness edit');
  restored = restored.replace(after, before);
  const bytes = Buffer.from(restored);
  assert.equal(bytes.length, original.bytes, 'full original source byte count');
  assert.equal(createHash('sha256').update(bytes).digest('hex'), original.sha256, 'all original helpers, bodies, assertions and seed inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), original.blob, 'original Git blob');
}

function validatePartitions(rows, actualWrappers) {
  assert.deepEqual(rows, ranges, 'only the eight reviewed complete ranges');
  for (const [path, first, last] of ranges.slice(1))
    assert.equal(actualWrappers[path], `assert(loadfile('${entry}'))(${first},${last})\n`, 'each complete executable tail wrapper');
  const seen = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(seen, Array.from({ length: 31 }, (_, i) => i + 1), 'all 31 original case identities exactly once');
}

test('eight original-budget card-help fixtures preserve the full source and all 31 case identities', () => {
  validateSource(originalSource());
  validatePartitions(ranges, wrappers());
  const discovered = readdirSync('tests/lua').filter(name => /^card_help_release.*\.lua$/.test(name)).map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, ranges.map(([path]) => path).sort(), 'raw Lua discovery includes all eight fixtures with no duplicate family');
  const runner = read('scripts/test-lua.mjs');
  assert.doesNotMatch(runner, /card_help_release/, 'no family-specific timeout exception');
  assert.match(runner, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
});

test('card-help source and coverage contracts reject deleted assertions, skipped ranges and inert wrappers', () => {
  const source = originalSource();
  const removedAssertion = source.replace("assert(same(s,before) and u.selected == nil)", 'assert(true)');
  assert.notEqual(removedAssertion, source, 'the negative control must alter a real original assertion');
  assert.throws(() => validateSource(removedAssertion), /original source byte count|original helpers/);
  assert.throws(() => validateSource(source.replace('registered<first or registered>last', 'true')), /range-registration harness/);
  assert.throws(() => validateSource(source.replace(footer, '')), /counts must remain enforced/);
  const skipped = ranges.map(row => [...row]); skipped[1][1]++;
  const overlap = ranges.map(row => [...row]); overlap[0][2]++;
  assert.throws(() => validatePartitions(skipped, wrappers()), /complete ranges/);
  assert.throws(() => validatePartitions(overlap, wrappers()), /complete ranges/);
  const inert = wrappers(); inert[ranges[1][0]] = '-- ' + inert[ranges[1][0]];
  assert.throws(() => validatePartitions(ranges, inert), /executable tail wrapper/);
});
