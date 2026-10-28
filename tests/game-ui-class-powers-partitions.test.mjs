import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => preFormalEntrySource(path,readFileSync(path,'utf8'));
const partitions = JSON.parse(read('tests/fixtures/game-ui-class-powers-partitions.json'));

test('class power raw partitions restore the exact original Git body and cover every matrix case once', () => {
  assert.equal(partitions.base, '0a773c1c8e736b564514c2c61adeaa6af541f023');
  assert.equal(partitions.entry, 'tests/lua/game_ui_class_powers.lua');
  assert.equal(partitions.originalSha256LF, '1065c2741373b7ab5e14405d655a10afedb77c6a4e10be7aa4a77dcc8b07727c');
  assert.equal(partitions.originalGitBlob, '78b385b579da7d67fac3c9d2345e916a19d5d28b');
  assert.equal(partitions.total, 30);
  assert.equal(partitions.timeoutMilliseconds, 30000);
  assert.equal(partitions.prefix, 'local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 5\nlocal sliceRegistered=0\n');
  assert.equal(partitions.before, 'for _,case in ipairs(cases) do\n');
  assert.equal(partitions.after, partitions.before + '    sliceRegistered=sliceRegistered+1\n    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then\n');
  assert.equal(partitions.endBefore, 'end\nprint("GAME_UI_CLASS_POWERS_PASS "..count)\n');
  assert.equal(partitions.endAfter, '    print("GAME_UI_CLASS_POWERS_CASE "..sliceRegistered)\n    end\n' + partitions.endBefore);
  assert.equal(partitions.footer, '\nassert(sliceRegistered==30,"all thirty original class power cases must register")\nassert(count==sliceLast-sliceFirst+1,"every selected original class power case must execute")\nprint("GAME_UI_CLASS_POWERS_SLICE "..sliceFirst.." "..sliceLast.." "..count)\n');
  assert.deepEqual(partitions.slices, Array.from({ length: 6 }, (_, index) => ({
    path: index ? `tests/lua/game_ui_class_powers_slice_${index + 1}.lua` : partitions.entry,
    first: index * 5 + 1, last: (index + 1) * 5,
  })));
  let original = read(partitions.entry);
  assert.ok(original.startsWith(partitions.prefix));
  assert.ok(original.endsWith(partitions.footer));
  original = original.slice(partitions.prefix.length, -partitions.footer.length);
  for (const [after, before] of [[partitions.after, partitions.before], [partitions.endAfter, partitions.endBefore]]) {
    assert.equal(original.split(after).length, 2, 'each selection edit has one exact inverse');
    original = original.replace(after, before);
  }
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
  assert.deepEqual(covered, Array.from({ length: 30 }, (_, index) => index + 1));
  const runner = read('scripts/test-lua.mjs');
  assert.match(runner, /readdirSync\('tests\/lua'\)/);
  assert.match(runner, /filter\(file => file\.endsWith\('\.lua'\)\)/);
});
