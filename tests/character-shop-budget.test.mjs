import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
test('character shop retains all four original groups and both complete seed matrices across original budgets', () => {
  const contract = JSON.parse(read('tests/fixtures/sts1-character-shop-budget.json'));
  assert.equal(contract.timeoutMilliseconds, 30000);
  assert.equal(contract.base, 'bcddf98aeabb7618ad56710926cd7aa4bf11b915');
  let source = read(contract.entry);
  for (const edit of [...contract.edits].reverse()) {
    assert.equal(source.split(edit.after).length, 2);
    source = source.replace(edit.after, edit.before);
  }
  assert.equal(createHash('sha256').update(source).digest('hex'), contract.migratedSourceSha256LF);
  assert.match(source, /for seed=1,8 do/);
  assert.match(source, /for seed=1,16 do/);
  assert.match(source, /ipairs\(\{'silent','defect','watcher'\}\)/);
  assert.match(source, /ipairs\(\{'silent','defect','watcher','ironclad'\}\)/);
  const classSplit = contract.edits.find(edit => edit.before === "for _,id in ipairs({'silent','defect','watcher','ironclad'}) do");
  assert.equal(classSplit.after, "for _,id in ipairs(part==2 and {'silent','defect'} or {'watcher','ironclad'}) do");
  assert.deepEqual(contract.parts.map(part => part.part), [1, 2, 3]);
  assert.deepEqual(contract.parts.flatMap(part => part.groups), [1, 2, 3, 4, 4]);
  assert.deepEqual(contract.poisonSeeds, Array.from({ length: 16 }, (_, i) => i + 1));
  const contexts = contract.parts.flatMap(part => part.poisonClasses.flatMap(id =>
    contract.poisonSeeds.map(seed => `${id}:${seed}`)));
  const expected = ['silent', 'defect', 'watcher', 'ironclad'].flatMap(id =>
    Array.from({ length: 16 }, (_, i) => `${id}:${i + 1}`));
  assert.deepEqual(contexts, expected, 'every original class/seed context occurs exactly once');
  assert.equal(contract.parts[0].file, 'character_shop.lua');
  for (const part of contract.parts.slice(1)) {
    assert.equal(read(`tests/lua/${part.file}`), `assert(loadfile('${contract.entry}'))(${part.part})\n`);
  }
});
