import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const partitions = JSON.parse(read('tests/fixtures/jaw-worm-ai-partitions.json'));

test('Jaw Worm raw partitions restore the exact original Git body and cover all original groups once', () => {
  assert.equal(partitions.base, '2f3879eb4b7bd7d08d83601e99c90cb82a5aceea');
  assert.equal(partitions.entry, 'tests/lua/jaw_worm_ai.lua');
  assert.equal(partitions.originalSha256LF, '4cfea5a462f3682c95d9cd7882d800a787e71d95722b2b32e499877d4b725560');
  assert.equal(partitions.originalGitBlob, '8b82d3ddf251a65bbac461279c0476baba2ab52f');
  assert.equal(partitions.total, 13);
  assert.equal(partitions.timeoutMilliseconds, 30000);
  assert.equal(partitions.prefix, 'local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 1\nlocal sliceRegistered=0\n');
  assert.equal(partitions.before, 'local function test(name,fn) fn(); count=count+1; print("ok jaw "..count.." - "..name) end');
  assert.equal(partitions.after, 'local function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    fn(); count=count+1; print("ok jaw "..count.." - "..name)\n    print("JAW_WORM_AI_CASE "..sliceRegistered)\nend');
  assert.equal(partitions.footer, '\nassert(sliceRegistered==13,"all thirteen original Jaw Worm groups must register")\nassert(count==sliceLast-sliceFirst+1,"every selected original Jaw Worm group must execute")\nprint("JAW_WORM_AI_SLICE "..sliceFirst.." "..sliceLast.." "..count)\n');
  assert.deepEqual(partitions.slices, [
    { path: partitions.entry, first: 1, last: 1 },
    { path: 'tests/lua/jaw_worm_ai_slice_2.lua', first: 2, last: 11 },
    { path: 'tests/lua/jaw_worm_ai_slice_3.lua', first: 12, last: 13 },
  ]);
  let original = read(partitions.entry);
  assert.ok(original.startsWith(partitions.prefix));
  assert.ok(original.endsWith(partitions.footer));
  original = original.slice(partitions.prefix.length, -partitions.footer.length);
  assert.equal(original.split(partitions.after).length, 2, 'the group selector has one exact inverse');
  original = original.replace(partitions.after, partitions.before);
  assert.equal(createHash('sha256').update(original).digest('hex'), partitions.originalSha256LF);
  const bytes = Buffer.from(original);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'), partitions.originalGitBlob);
  const rawFiles = readdirSync('tests/lua').filter(name => name.endsWith('.lua'));
  const covered = [];
  for (const [index, part] of partitions.slices.entries()) {
    assert.ok(rawFiles.includes(part.path.replace('tests/lua/', '')), 'the raw runner discovers every partition');
    if (index) assert.equal(read(part.path), `assert(loadfile("${partitions.entry}"))(${part.first},${part.last})\n`);
    for (let group = part.first; group <= part.last; group++) covered.push(group);
  }
  assert.deepEqual(covered, Array.from({ length: 13 }, (_, index) => index + 1));
  const runner = read('scripts/test-lua.mjs');
  assert.match(runner, /readdirSync\('tests\/lua'\)/);
  assert.match(runner, /filter\(file => file\.endsWith\('\.lua'\)\)/);
});
