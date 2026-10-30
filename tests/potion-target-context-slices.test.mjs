import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { originalLuaRunner } from './helpers/ci-lua-runner-inverse.mjs';
import {originalMainPotionFixture,assertMainPotionActionHelper} from './helpers/main-potion-fixture-inverse.mjs';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = source => createHash('sha256').update(source).digest('hex');
const entry = 'tests/lua/battle_ui_potion_target_context.lua';
const tail = 'tests/lua/battle_ui_potion_target_context_slice_2.lua';
const helper = 'tests/lua/support/potion_targeting_fixture.lua';
const original = {
  bytes: 2235,
  sha256: 'a0eb6e932e1e241b30df910efab24c58c58e0ae0e6cb3498ed39e32184dc40f7',
  blob: '2838cf9c8eb201ddcf8deba7d2420e412713a2c2',
  helperSha256: 'b946de63bf3a5be568d69b04fc89062abbdb146f03058eddca081d6951bda36c',
  runnerSha256: '63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b',
};
// Only range selection wraps the existing suite. Restore the entire original
// byte sequence, including its first three lines, every loop and finish().
const prefix = "local first,last=...\nfirst,last=first or 1,last or 4\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=8 and first<=last,'invalid potion context slice')\nlocal registered,executed=0,0\n";
const before = 'local test,finish = H.suite("LUA_POTION_TARGET_CONTEXT")\n';
const middle = 'local originalTest=test\ntest=function(name,fn)\n registered=registered+1\n if registered<first or registered>last then return end\n executed=executed+1\n return originalTest(name,fn)\nend\n';
const footer = "assert(registered==8,'all original potion context cases must register')\nassert(executed==last-first+1,'all selected potion context cases must execute')\nprint('POTION_TARGET_CONTEXT_PART '..first..' '..last..' '..executed)\n";
const ranges = [[entry, 1, 4], [tail, 5, 8]];

function validateSource(source) {
  source=originalMainPotionFixture(source,entry);
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

function validatePartitions(rows, wrapper) {
  assert.deepEqual(rows, ranges, 'only the two reviewed complete ranges');
  assert.equal(wrapper, `assert(loadfile('${entry}'))(5,8)\n`, 'complete executable tail wrapper');
  const covered = rows.flatMap(([, first, last]) => Array.from({ length: last - first + 1 }, (_, i) => first + i));
  assert.deepEqual(covered, [1, 2, 3, 4, 5, 6, 7, 8], 'all eight registered identities exactly once');
}

function validateHelper(source) {
  assertMainPotionActionHelper();
  source=originalMainPotionFixture(source,helper);
  assert.equal(sha(source), original.helperSha256, 'unchanged fresh seed-61 setup and shared helper');
}

function validateRunner(source) {
  assert.equal(sha(originalLuaRunner(source)), original.runnerSha256, 'unchanged runner and deadlines');
  assert.doesNotMatch(source, /battle_ui_potion_target_context/, 'no family-specific timeout exception');
  assert.match(source, /fixture \|\| composedHost \? 60000 : 30000;/, 'keep the existing 30-second default fixture budget');
}

historicalTest('two original-budget potion context fixtures preserve the full eight-case source and fresh inputs', () => {
  validateSource(read(entry));
  validateHelper(read(helper));
  validateRunner(read('scripts/test-lua.mjs'));
  validatePartitions(ranges, read(tail));
  const discovered = readdirSync('tests/lua').filter(name => /^battle_ui_potion_target_context(?:_slice_\d+)?\.lua$/.test(name))
    .map(name => 'tests/lua/' + name).sort();
  assert.deepEqual(discovered, [entry, tail], 'raw Lua discovery contains both complete ranges without duplicates');
});

historicalTest('potion context inverse and coverage guards reject lost assertions, skipped cases, inert wrappers and input drift', () => {
  const source = read(entry);
  const lostAssertion = source.replace('assert(Run.endTurn(h.run))', 'assert(true)');
  assert.notEqual(lostAssertion, source, 'negative control must alter a real original assertion');
  assert.throws(() => validateSource(lostAssertion), /original source byte count|original helpers/);
  assert.throws(() => validateSource(source.replace('registered<first or registered>last', 'true')), /range-registration harness/);
  assert.throws(() => validateSource(source.replace(footer, '')), /counts must remain enforced/);
  assert.throws(() => validatePartitions([[entry, 1, 4], [tail, 6, 8]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions([[entry, 1, 5], [tail, 5, 8]], read(tail)), /complete ranges/);
  assert.throws(() => validatePartitions(ranges, '-- ' + read(tail)), /executable tail wrapper/);
  const changedSeed = read(helper).replace('Run.new(F.Data,61)', 'Run.new(F.Data,62)');
  assert.notEqual(changedSeed, read(helper), 'negative control must alter the actual seed-61 fixture');
  assert.throws(() => validateHelper(changedSeed), /fresh seed-61 setup/);
  const runner = preAcceptedPr323Source('scripts/test-lua.mjs',read('scripts/test-lua.mjs'));
  const longerDeadline = runner.replace('60000 : 30000', '60000 : 60000');
  assert.notEqual(longerDeadline, runner, 'negative control must alter the real deadline');
  assert.throws(() => validateRunner(longerDeadline), /unchanged runner and deadlines/);
});

test('current potion context discovery and wrappers retain both complete ranges and the ordinary budget',()=>{
  validatePartitions(ranges,read(tail));
  const discovered=readdirSync('tests/lua').filter(name=>/^battle_ui_potion_target_context(?:_slice_\d+)?\.lua$/.test(name)).map(name=>'tests/lua/'+name).sort();
  assert.deepEqual(discovered,[entry,tail]);
  const runner=read('scripts/test-lua.mjs');
  assert.doesNotMatch(runner,/battle_ui_potion_target_context/);
  assert.match(runner,/fixture \|\| composedHost \? 60000 : 30000;/);
});
