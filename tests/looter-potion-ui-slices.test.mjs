import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = source => createHash('sha256').update(source).digest('hex');
const entry = 'tests/lua/looter_potion_ui.lua';
const tail = 'tests/lua/looter_potion_ui_slice_2.lua';
const helper = 'tests/lua/support/looter_potion_ui_fixture.lua';
// Full original LF source at develop e0fad45c74ed574bc4cfb8a4c9ad71424a13c386.
// Eight groups create 1+1+2+4+1+1+8+4 independent seed-42 reward fixtures.
const original = {
  bytes: 4525,
  sha256: '730f8c33080a66916981f912c8fece20a002eceba8bd3771b9c0619481871a68',
  blob: '232311b7e68a0127ce487c02137a90ff099a5a1b',
  helperSha256: 'c68bcd6d44ebbd5193875c9003e95e8643b97a083c1cbbe4eb5390f629c4c43e',
};
// Original-group profiling: 1–6 ~11.89s (10 setups), 7–8 ~13.81s (12 setups).
// No gameplay, shared helper, mutable host reuse or timeout changes.
const prefix = "local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 6\nassert(sliceFirst>=1 and sliceLast<=8 and sliceFirst<=sliceLast,'invalid looter UI slice')\nlocal sliceRegistered,sliceExecuted=0,0\n";
const before = 'local function test(name,fn) ';
const after = "local function test(name,fn)\n sliceRegistered=sliceRegistered+1\n if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n sliceExecuted=sliceExecuted+1\n print('LOOTER_POTION_UI_CASE '..sliceRegistered..' '..name)\n ";
const footer = "assert(sliceRegistered==8,'all original looter UI groups must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'all selected looter UI groups must execute')\nprint('LOOTER_POTION_UI_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n";

function validateSource(source) {
  assert.ok(source.startsWith(prefix), 'only the reviewed original-budget range prefix');
  assert.ok(source.endsWith(footer), 'registration and execution counts must remain enforced');
  let restored = source.slice(prefix.length, -footer.length);
  assert.equal(restored.split(after).length, 2, 'one exact range-registration harness edit');
  restored = restored.replace(after, before);
  const bytes = Buffer.from(restored);
  assert.equal(bytes.length, original.bytes, 'full original source byte count');
  assert.equal(sha(bytes), original.sha256, 'all original helpers, bodies, assertions and inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), original.blob, 'original Git blob');
}

function validatePartitions(rows, wrapper) {
  assert.deepEqual(rows, [[entry, 1, 6], [tail, 7, 8]], 'only the two reviewed complete ranges');
  assert.equal(wrapper, `assert(loadfile('${entry}'))(7,8)\n`, 'the complete executable tail wrapper');
  const seen = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(seen, Array.from({ length: 8 }, (_, i) => i + 1), 'all eight original group identities exactly once');
}

function validateHelper(source) {
  assert.equal(sha(source), original.helperSha256, 'unchanged fresh seed-42 reward fixture and shared helper');
}

test('two original-budget looter UI fixtures preserve all eight groups and 22 fresh reward setups', () => {
  validateSource(read(entry));
  validateHelper(read(helper));
  validatePartitions([[entry, 1, 6], [tail, 7, 8]], read(tail));
  const discovered = readdirSync('tests/lua').filter(name => /^looter_potion_ui(?:_slice_\d+)?\.lua$/.test(name)).map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, [entry, tail], 'raw Lua discovery includes both original-parent ranges exactly once');
  const runner = read('scripts/test-lua.mjs');
  assert.doesNotMatch(runner, /looter_potion_ui/, 'no family-specific timeout exception');
  assert.match(runner, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
});

test('looter UI source and coverage contracts reject lost assertions, skipped groups, inert wrappers and seed drift', () => {
  const source = read(entry);
  const removedAssertion = source.replace("assert(resolvedAction(h,name),'animation swallowed '..name)", 'assert(true)');
  assert.notEqual(removedAssertion, source, 'the negative control must alter a real original assertion');
  assert.throws(() => validateSource(removedAssertion), /original source byte count|original helpers/);
  assert.throws(() => validateSource(source.replace('sliceRegistered<sliceFirst or sliceRegistered>sliceLast', 'true')), /range-registration harness/);
  assert.throws(() => validateSource(source.replace(footer, '')), /counts must remain enforced/);
  assert.throws(() => validatePartitions([[entry, 1, 6], [tail, 8, 8]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 7], [tail, 7, 8]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 6], [tail, 7, 8]], '-- ' + read(tail)), /executable tail wrapper/);
  const changedSeed = read(helper).replace('Run.new(H.F.Data,42)', 'Run.new(H.F.Data,43)');
  assert.notEqual(changedSeed, read(helper), 'the negative control must alter the real reward seed');
  assert.throws(() => validateHelper(changedSeed), /fresh seed-42 reward fixture/);
});
