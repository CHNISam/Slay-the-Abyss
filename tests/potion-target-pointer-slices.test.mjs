import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { originalLuaRunner } from './helpers/ci-lua-runner-inverse.mjs';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = source => createHash('sha256').update(source).digest('hex');
const entry = 'tests/lua/battle_ui_potion_target_pointers.lua';
const tails = [2,3,4].map(n => `tests/lua/battle_ui_potion_target_pointers_slice_${n}.lua`);
const helper = 'tests/lua/support/potion_targeting_fixture.lua';
const original = {
  bytes: 2815,
  sha256: 'c91c5b9a4c6fd8d4ce75dbce26ce7483f41459327520ec8176da63faf5edfbec',
  blob: '60a78e9038eb58fdfefa92c5d50c4bb2ea0440f6',
  helperSha256: 'b946de63bf3a5be568d69b04fc89062abbdb146f03058eddca081d6951bda36c',
  runnerSha256: '63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b',
};
// Only range selection wraps the existing suite. Restore the entire original
// byte sequence, including its first three lines, every loop and finish().
const prefix = "local first,last=...\nfirst,last=first or 1,last or 2\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=7 and first<=last,'invalid potion pointer slice')\nlocal registered,executed=0,0\n";
const before = 'local test,finish = H.suite("LUA_POTION_TARGET_POINTERS")\n';
const middle = 'local originalTest=test\ntest=function(name,fn)\n registered=registered+1\n if registered<first or registered>last then return end\n executed=executed+1\n return originalTest(name,fn)\nend\n';
const footer = "assert(registered==7,'all original potion pointer cases must register')\nassert(executed==last-first+1,'all selected potion pointer cases must execute')\nprint('POTION_TARGET_POINTER_PART '..first..' '..last..' '..executed)\n";
const ranges = [[entry, 1, 2], [tails[0], 3, 4], [tails[1], 5, 6], [tails[2], 7, 7]];

function validateSource(source) {
  assert.ok(source.startsWith(prefix), 'only the reviewed original-budget range prefix');
  assert.ok(source.endsWith('finish()\n' + footer), 'original finish and registration/execution counts must remain enforced');
  let restored = source.slice(prefix.length, -footer.length);
  assert.equal(restored.split(before + middle).length, 2, 'one exact range-registration harness edit');
  restored = restored.replace(before + middle, before);
  const bytes = Buffer.from(restored);
  assert.equal(bytes.length, original.bytes, 'full original source byte count');
  assert.equal(sha(bytes), original.sha256, 'all original helpers, bodies, assertions and inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), original.blob, 'original Git blob');
}

function validatePartitions(rows, wrappers) {
  assert.deepEqual(rows, ranges, 'only the four reviewed complete ranges');
  for (const [i, [, first, last]] of ranges.slice(1).entries()) assert.equal(wrappers[i], `assert(loadfile('${entry}'))(${first},${last})\n`, 'complete executable tail wrapper');
  const covered = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(covered, [1, 2, 3, 4, 5, 6, 7], 'all seven registered identities exactly once');
}

function validateHelper(source) {
  assert.equal(sha(source), original.helperSha256, 'unchanged fresh seed-61 setup and shared helper');
}

function validateRunner(source) {
  assert.equal(sha(originalLuaRunner(source)), original.runnerSha256, 'unchanged runner and deadlines');
  assert.doesNotMatch(source, /battle_ui_potion_target_pointers/, 'no family-specific timeout exception');
  assert.match(source, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
}

test('four original-budget potion pointer fixtures preserve the full seven-case source and fresh inputs', () => {
  validateSource(read(entry));
  validateHelper(read(helper));
  validateRunner(read('scripts/test-lua.mjs'));
  validatePartitions(ranges, tails.map(read));
  const discovered = readdirSync('tests/lua').filter(name => /^battle_ui_potion_target_pointers(?:_slice_\d+)?\.lua$/.test(name))
    .map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, [entry, ...tails], 'raw Lua discovery contains all four complete ranges without duplicates');
});

test('potion pointer inverse and coverage guards reject lost assertions, skipped cases, inert wrappers and input drift', () => {
  const source = read(entry);
  const lostAssertion = source.replace("eq(h.run.potions[1],'fire_potion')", 'assert(true)');
  assert.notEqual(lostAssertion, source, 'negative control must alter a real original assertion');
  assert.throws(() => validateSource(lostAssertion), /original source byte count|original helpers/);
  assert.throws(() => validateSource(source.replace('registered<first or registered>last', 'true')), /range-registration harness/);
  assert.throws(() => validateSource(source.replace(footer, '')), /counts must remain enforced/);
  assert.throws(() => validatePartitions([[entry, 1, 2], [tails[0], 4, 4], ...ranges.slice(2)], tails.map(read)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 3], ...ranges.slice(1)], tails.map(read)), /complete ranges/);
  assert.throws(() => validatePartitions(ranges, tails.map(path => '-- ' + read(path))), /executable tail wrapper/);
  const changedSeed = read(helper).replace('Run.new(F.Data,61)', 'Run.new(F.Data,62)');
  assert.notEqual(changedSeed, read(helper), 'negative control must alter the actual seed-61 fixture');
  assert.throws(() => validateHelper(changedSeed), /fresh seed-61 setup/);
  const longerDeadline = read('scripts/test-lua.mjs').replace('60000 : 30000', '60000 : 60000');
  assert.notEqual(longerDeadline, read('scripts/test-lua.mjs'), 'negative control must alter the real deadline');
  assert.throws(() => validateRunner(longerDeadline), /unchanged runner and deadlines/);
});
