import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = source => createHash('sha256').update(source).digest('hex');
const entry = 'tests/fixtures/js-owned/tests/lua/looter_potion_ui.lua';
const helper = 'tests/lua/support/looter_potion_ui_fixture.lua';
// Full original LF source at develop e0fad45c74ed574bc4cfb8a4c9ad71424a13c386.
// Eight groups create 1+1+2+4+1+1+8+4 independent seed-42 reward fixtures.
const original = {
  bytes: 4525,
  sha256: '730f8c33080a66916981f912c8fece20a002eceba8bd3771b9c0619481871a68',
  blob: '232311b7e68a0127ce487c02137a90ff099a5a1b',
  helperSha256: 'c68bcd6d44ebbd5193875c9003e95e8643b97a083c1cbbe4eb5390f629c4c43e',
};
// PR262 keeps one whole original group per executable range, rather than
// adding PR263's overlapping 1–6 / 7–8 ranges. No helper or timeout changes.
const prefix = "local first,last=...\nfirst,last=first or 1,last or 1\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=8 and first<=last,'invalid UI budget slice')\nlocal registered=0\n";
const before = 'local function test(name,fn) ';
const after = before + 'registered=registered+1;if registered<first or registered>last then return end; ';
const footer = "assert(registered==8,'original UI case discovery changed')\nassert(passed+failed==last-first+1,'UI budget slice coverage changed')\n";
const summary = "print('LOOTER_POTION_UI '..passed..' passed '..failed..' failed');assert(failed==0)\n";
const ranges = Array.from({ length: 8 }, (_, i) => [
  i === 0 ? entry : `tests/fixtures/js-owned/tests/lua/looter_potion_ui_slice_${i + 1}.lua`, i + 1, i + 1,
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
  assert.equal(sha(bytes), original.sha256, 'all original helpers, bodies, assertions and inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), original.blob, 'original Git blob');
}

function validatePartitions(rows, actualWrappers) {
  assert.deepEqual(rows, ranges, 'only the eight reviewed complete ranges');
  for (const [path, first, last] of ranges.slice(1))
    assert.equal(actualWrappers[path], `assert(loadfile('${entry}'))(${first},${last})\n`, 'each complete executable tail wrapper');
  const seen = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(seen, Array.from({ length: 8 }, (_, i) => i + 1), 'all eight original group identities exactly once');
}

function validateHelper(source) {
  assert.equal(sha(source), original.helperSha256, 'unchanged fresh seed-42 reward fixture and shared helper');
}

test('eight original-budget looter UI fixtures preserve all eight groups and 22 fresh reward setups', () => {
  validateSource(read(entry));
  validateHelper(read(helper));
  validatePartitions(ranges, wrappers());
  const discovered = readdirSync('tests/lua').filter(name => /^looter_potion_ui(?:_slice_\d+)?\.lua$/.test(name)).map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, ranges.map(([path]) => path).sort(), 'raw Lua discovery includes all eight original-parent ranges exactly once');
  const runner = read('scripts/test-lua.mjs');
  assert.doesNotMatch(runner, /looter_potion_ui/, 'no family-specific timeout exception');
  assert.match(runner, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
});

test('looter UI source and coverage contracts reject lost assertions, skipped groups, inert wrappers and seed drift', () => {
  const source = read(entry);
  const removedAssertion = source.replace("assert(resolvedAction(h,name),'animation swallowed '..name)", 'assert(true)');
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
  const changedSeed = read(helper).replace('Run.new(H.F.Data,42)', 'Run.new(H.F.Data,43)');
  assert.notEqual(changedSeed, read(helper), 'the negative control must alter the real reward seed');
  assert.throws(() => validateHelper(changedSeed), /fresh seed-42 reward fixture/);
});
