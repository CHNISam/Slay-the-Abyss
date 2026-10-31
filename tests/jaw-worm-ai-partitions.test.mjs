import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const partitions = JSON.parse(read('tests/fixtures/jaw-worm-ai-partitions.json'));

function assertCoverage(slices) {
  const covered = [];
  for (const part of slices) {
    for (let group=part.first; group<=part.last; group++) {
      if (group===12) {
        assert.ok(Number.isInteger(part.seedFirst) && Number.isInteger(part.seedLast));
        assert.ok(part.seedFirst>=0 && part.seedLast<=15 && part.seedFirst<=part.seedLast);
        for (let seed=part.seedFirst; seed<=part.seedLast; seed++) covered.push(`${group}:${seed}`);
      } else {
        assert.equal(part.seedFirst,undefined);
        assert.equal(part.seedLast,undefined);
        covered.push(String(group));
      }
    }
  }
  const expected = Array.from({length:13},(_,index)=>index+1)
    .flatMap(group=>group===12?Array.from({length:16},(_,seed)=>`${group}:${seed}`):[String(group)]);
  assert.deepEqual(covered,expected,'all original groups and all sixteen live-round seeds execute exactly once');
}

test('Jaw Worm raw partitions restore the exact original Git body and cover all original groups and seeds once', () => {
  assert.equal(partitions.base, '2f3879eb4b7bd7d08d83601e99c90cb82a5aceea');
  assert.equal(partitions.entry, 'tests/lua/jaw_worm_ai.lua');
  assert.equal(partitions.originalSha256LF, '4cfea5a462f3682c95d9cd7882d800a787e71d95722b2b32e499877d4b725560');
  assert.equal(partitions.originalGitBlob, '8b82d3ddf251a65bbac461279c0476baba2ab52f');
  assert.equal(partitions.total, 13);
  assert.equal(partitions.timeoutMilliseconds, 30000);
  assert.equal(partitions.prefix, 'local sliceFirst,sliceLast,seedFirst,seedLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 1\nseedFirst,seedLast=seedFirst or 0,seedLast or 15\nassert(seedFirst>=0 and seedLast<=15 and seedFirst<=seedLast,"valid original seed partition")\nlocal sliceRegistered=0\n');
  assert.equal(partitions.before, 'local function test(name,fn) fn(); count=count+1; print("ok jaw "..count.." - "..name) end');
  assert.equal(partitions.after, 'local function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    fn(); count=count+1; print("ok jaw "..count.." - "..name)\n    print("JAW_WORM_AI_CASE "..sliceRegistered)\nend');
  assert.equal(partitions.footer, '\nassert(sliceRegistered==13,"all thirteen original Jaw Worm groups must register")\nassert(count==sliceLast-sliceFirst+1,"every selected original Jaw Worm group must execute")\nprint("JAW_WORM_AI_SLICE "..sliceFirst.." "..sliceLast.." "..count)\n');
  assert.deepEqual(partitions.slices, [
    { path: partitions.entry, first: 1, last: 1 },
    { path: 'tests/lua/jaw_worm_ai_slice_2.lua', first: 2, last: 11 },
    { path: 'tests/lua/jaw_worm_ai_slice_3.lua', first: 12, last: 12, seedFirst:0, seedLast:3 },
    { path: 'tests/lua/jaw_worm_ai_slice_4.lua', first: 12, last: 12, seedFirst:4, seedLast:7 },
    { path: 'tests/lua/jaw_worm_ai_slice_5.lua', first: 12, last: 12, seedFirst:8, seedLast:11 },
    { path: 'tests/lua/jaw_worm_ai_slice_6.lua', first: 12, last: 12, seedFirst:12, seedLast:15 },
    { path: 'tests/lua/jaw_worm_ai_slice_7.lua', first: 13, last: 13 },
  ]);
  let original = read(partitions.entry);
  assert.ok(original.startsWith(partitions.prefix));
  assert.ok(original.endsWith(partitions.footer));
  original = original.slice(partitions.prefix.length, -partitions.footer.length);
  assert.equal(original.split(partitions.after).length, 2, 'the group selector has one exact inverse');
  original = original.replace(partitions.after, partitions.before);
  assert.equal(original.split('for seed=seedFirst,seedLast do').length,2,'one exact seed-loop inverse');
  original = original.replace('for seed=seedFirst,seedLast do','for seed=0,15 do');
  assert.equal(createHash('sha256').update(original).digest('hex'), partitions.originalSha256LF);
  const bytes = Buffer.from(original);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), partitions.originalGitBlob);
  const rawFiles = readdirSync('tests/lua').filter(name => name.endsWith('.lua'));
  assert.deepEqual(rawFiles.filter(name=>/^jaw_worm_ai(?:_slice_\d+)?\.lua$/.test(name)).sort(),
    partitions.slices.map(part=>part.path.replace('tests/lua/','')).sort(),'no undisclosed or missing raw entry');
  for (const [index, part] of partitions.slices.entries()) {
    assert.ok(rawFiles.includes(part.path.replace('tests/lua/', '')), 'the raw runner discovers every partition');
    const seedArgs=part.seedFirst===undefined?'':`,${part.seedFirst},${part.seedLast}`;
    if (index) assert.equal(read(part.path), `assert(loadfile("${partitions.entry}"))(${part.first},${part.last}${seedArgs})\n`);
  }
  assertCoverage(partitions.slices);
  const runner = read('scripts/test-lua.mjs');
  assert.match(runner, /readdirSync\('tests\/lua'\)/);
  assert.match(runner, /filter\(file => file\.endsWith\('\.lua'\)\)/);
});

test('Jaw Worm seed coverage rejects omitted, duplicated and out-of-range live-round work', () => {
  for (const change of [
    slices=>slices.splice(3,1),
    slices=>{slices[2].seedLast=2;},
    slices=>{slices[3].seedFirst=3;},
    slices=>{slices[5].seedLast=16;},
  ]) {
    const slices=structuredClone(partitions.slices);
    change(slices);
    assert.throws(()=>assertCoverage(slices));
  }
});
