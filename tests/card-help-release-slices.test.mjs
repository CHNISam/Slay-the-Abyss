import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const entry = 'tests/lua/card_help_release.lua';
const tail = 'tests/lua/card_help_release_slice_2.lua';
// Full original LF source at b420e8b267bbdbf2d5d7c68bc7d893faa130047c,
// unchanged from develop d16be8db. Includes helpers, every case body and loop.
const original = {
  bytes: 11056,
  sha256: '088862441fab127f5f29dee6cc990ab39b59152e57250310386bae6b8f3808f2',
  blob: '30be7f602416c592771604abcc4a80ba30ae8386',
};
const prefix = "local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 16\nassert(sliceFirst>=1 and sliceLast<=31 and sliceFirst<=sliceLast,'invalid card-help slice')\nlocal sliceRegistered,sliceExecuted=0,0\n";
const before = 'local function test(name, fn)\n';
const after = before + "    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    sliceExecuted=sliceExecuted+1\n    print('CARD_HELP_RELEASE_CASE '..sliceRegistered..' '..name)\n";
const footer = "assert(sliceRegistered==31,'all original card-help cases must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'all selected card-help cases must execute')\nprint('CARD_HELP_RELEASE_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n";

function validateSource(source) {
  assert.ok(source.startsWith(prefix), 'only the reviewed original-budget range prefix');
  assert.ok(source.endsWith(footer), 'registration and execution counts must remain enforced');
  let restored = source.slice(prefix.length, -footer.length);
  assert.equal(restored.split(after).length, 2, 'one exact range-registration harness edit');
  restored = restored.replace(after, before);
  const bytes = Buffer.from(restored);
  assert.equal(bytes.length, original.bytes, 'full original source byte count');
  assert.equal(createHash('sha256').update(bytes).digest('hex'), original.sha256, 'all original helpers, bodies, assertions and seed inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), original.blob, 'original Git blob');
}

function validatePartitions(rows, wrapper) {
  assert.deepEqual(rows, [[entry, 1, 16], [tail, 17, 31]], 'only the two reviewed complete ranges');
  assert.equal(wrapper, `assert(loadfile('${entry}'))(17,31)\n`, 'the complete executable tail wrapper');
  const seen = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(seen, Array.from({ length: 31 }, (_, i) => i + 1), 'all 31 original case identities exactly once');
}

test('two original-budget card-help fixtures preserve the full source and all 31 case identities', () => {
  validateSource(read(entry));
  validatePartitions([[entry, 1, 16], [tail, 17, 31]], read(tail));
  const discovered = readdirSync('tests/lua').filter(name => /^card_help_release.*\.lua$/.test(name)).map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, [entry, tail], 'raw Lua discovery includes both fixtures with no extra duplicate family');
  const runner = read('scripts/test-lua.mjs');
  assert.doesNotMatch(runner, /card_help_release/, 'no family-specific timeout exception');
  assert.match(runner, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
});

test('card-help source and coverage contracts reject deleted assertions, skipped ranges and inert wrappers', () => {
  const source = read(entry);
  const removedAssertion = source.replace("assert(same(s,before) and u.selected == nil)", 'assert(true)');
  assert.notEqual(removedAssertion, source, 'the negative control must alter a real original assertion');
  assert.throws(() => validateSource(removedAssertion), /original source byte count|original helpers/);
  assert.throws(() => validateSource(source.replace('sliceRegistered<sliceFirst or sliceRegistered>sliceLast', 'true')), /range-registration harness/);
  assert.throws(() => validateSource(source.replace(footer, '')), /counts must remain enforced/);
  assert.throws(() => validatePartitions([[entry, 1, 16], [tail, 18, 31]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 17], [tail, 17, 31]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 16], [tail, 17, 31]], '-- ' + read(tail)), /executable tail wrapper/);
});
