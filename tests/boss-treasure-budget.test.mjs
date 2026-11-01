import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
test('Boss chest parts preserve the complete reviewed migration and execute each of eight groups once', () => {
  const contract = JSON.parse(read('tests/fixtures/sts1-boss-treasure-budget.json'));
  assert.equal(contract.base, '2425ad622eed31ad6a965b90086a6838a1db96f4');
  assert.equal(contract.timeoutMilliseconds, 30000);
  let source = read(contract.entry);
  for (const edit of [...contract.edits].reverse()) {
    assert.equal(source.split(edit.after).length, 2, 'every partition edit is unique');
    source = source.replace(edit.after, edit.before);
  }
  assert.equal(createHash('sha256').update(source).digest('hex'), contract.migratedSourceSha256LF);
  assert.equal((source.match(/^test\(/gm) || []).length, 8);
  assert.deepEqual(contract.parts.map(part => part.part), [1, 2]);
  assert.deepEqual(contract.parts.flatMap(part => part.groups), [1, 2, 3, 4, 5, 6, 7, 8]);
  assert.equal(contract.parts[0].file, 'boss_treasure.lua');
  assert.equal(read(`tests/lua/${contract.parts[1].file}`), `assert(loadfile('${contract.entry}'))(2)\n`);
});
