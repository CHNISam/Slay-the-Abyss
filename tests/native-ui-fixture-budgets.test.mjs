import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = text => createHash('sha256').update(text).digest('hex');
// Original complete files at 07bf1af. Only the reversible registration harness
// may change; helpers, case bodies, loops, strict mocks and assertions stay intact.
const fixtures = [
  { stem: 'card_help_release', total: 31, ranges: [[1,5],[6,10],[11,15],[16,20],[21,25],[26,31]],
    originalSha: '088862441fab127f5f29dee6cc990ab39b59152e57250310386bae6b8f3808f2',
    before: 'local function test(name, fn)\n', marker: 'CARD_HELP_RELEASE' },
  { stem: 'looter_potion_ui', total: 8, ranges: [[1,3],[4,6],[7,7],[8,8]],
    originalSha: '730f8c33080a66916981f912c8fece20a002eceba8bd3771b9c0619481871a68',
    before: 'local function test(name,fn) ', marker: 'LOOTER_POTION_UI' },
];
const entry = fixture => `tests/lua/${fixture.stem}.lua`;
const files = fixture => fixture.ranges.map((_, index) =>
  index ? `tests/lua/${fixture.stem}_slice_${index + 1}.lua` : entry(fixture));
const prefix = fixture => `local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or ${fixture.ranges[0][0]},sliceLast or ${fixture.ranges[0][1]}\nlocal sliceRegistered=0\n`;
const gate = fixture => `    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    print('${fixture.marker}_CASE '..sliceRegistered)\n`;
const footer = fixture => `\nassert(sliceRegistered==${fixture.total},'all original ${fixture.stem} cases must register')\nassert(passed==sliceLast-sliceFirst+1,'every selected ${fixture.stem} case must pass')\nprint('${fixture.marker}_SLICE '..sliceFirst..' '..sliceLast..' '..passed)\n`;
function checkBody(fixture, source) {
  assert.ok(source.startsWith(prefix(fixture)), 'bounded default registration prefix');
  assert.ok(source.endsWith(footer(fixture)), 'complete registration and execution checks');
  const after = fixture.before + gate(fixture);
  assert.equal(source.split(after).length, 2, 'one reversible selection gate');
  const original = source.slice(prefix(fixture).length, -footer(fixture).length).replace(after, fixture.before);
  assert.equal(sha(original), fixture.originalSha, 'original complete fixture body');
}
function checkDiscovery(fixture, sources) {
  const paths = files(fixture);
  assert.deepEqual(Object.keys(sources).sort(), paths.toSorted(), 'raw discovery includes exactly the declared slices');
  const seen = [];
  for (const [index, [first, last]] of fixture.ranges.entries()) {
    if (index) assert.equal(sources[paths[index]], `assert(loadfile('${entry(fixture)}'))(${first},${last})\n`, 'slice selects its declared original cases');
    else assert.ok(sources[paths[index]].startsWith(prefix(fixture)), 'raw default selects first range');
    for (let group = first; group <= last; group++) seen.push(group);
  }
  assert.deepEqual(seen, Array.from({ length: fixture.total }, (_, i) => i + 1), 'every original group exactly once');
}

for (const fixture of fixtures) {
  test(`${fixture.stem} budget slices retain every original case body and assertion`, () => {
    const source = read(entry(fixture));
    checkBody(fixture, source);
    assert.throws(() => checkBody(fixture, source.replace('assert(', 'assert(true or ')), /original complete fixture body/,
      'removing or weakening an original assertion must be detected');
  });
  test(`${fixture.stem} raw discovery covers every original group exactly once`, () => {
    const matcher = new RegExp(`^${fixture.stem}(?:_slice_\\d+)?\\.lua$`);
    const sources = Object.fromEntries(readdirSync('tests/lua').filter(file => matcher.test(file))
      .map(file => [`tests/lua/${file}`, read(`tests/lua/${file}`)]));
    checkDiscovery(fixture, sources);
    const second = files(fixture)[1];
    assert.throws(() => checkDiscovery(fixture, { ...sources, [second]: `assert(loadfile('${entry(fixture)}'))(1,1)\n` }),
      /slice selects its declared original cases/, 'overlapping slice selection must be detected');
    const missing = { ...sources }; delete missing[second];
    assert.throws(() => checkDiscovery(fixture, missing), /raw discovery includes exactly the declared slices/,
      'missing raw entry must be detected');
  });
}
// These fixtures had no JS execution wrapper. Keep the guard static so npm test
// does not duplicate the expensive cases already run by ordinary raw discovery.
test('native UI slices keep ordinary discovery and the unchanged default 30-second budget', () => {
  const runner = read('scripts/test-lua.mjs');
  assert.match(runner, /readdirSync\('tests\/lua'\)/);
  assert.match(runner, /filter\(file => file\.endsWith\('\.lua'\)\)/);
  assert.match(runner, /timeout \?\?= normalizedScript\.endsWith\('tests\/lua\/encounter_coverage\.lua'\) \? 120000 : mapProperties \? 120000 : fixture \|\| composedHost \? 60000 : 30000;/);
  for (const fixture of fixtures) assert.ok(!runner.includes(fixture.stem), 'no per-fixture timeout exception');
});
