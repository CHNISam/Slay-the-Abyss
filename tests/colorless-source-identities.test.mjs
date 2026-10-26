import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(path, 'utf8');
const registration = JSON.parse(read('data/reference/sts1-card-pools/registration.json')).registration;
const snake = name => name.replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
  .replace(/([a-z\d])([A-Z])/g, '$1_$2').toLowerCase();
// Scope by fixed source class/path, never by the candidate sourceId being tested.
const expected = new Map(registration.filter(row => row.sourcePath.startsWith('cards/colorless/'))
  .map(row => [snake(row.class), row]));
const source = read('src/lua/abyss_colorless_cards.lua');
function verify(text) {
  const rows = [...text.matchAll(/card\('([^']*)','[^']*','([^']*)'/g)]
    .map(match => [match[1], match[2]]);
  assert.equal(expected.size, 39, 'fixed source scope');
  assert.equal(rows.length, 39, 'all local colorless definitions');
  const actual = new Map(rows);
  assert.equal(actual.size, 39, 'unique stable local IDs');
  for (const [id, row] of expected) {
    assert.equal(actual.get(id), row.id, `sourceId for ${id} (fixed class ${row.class})`);
  }
}

test('all 39 colorless source IDs match their fixed registration classes', () => verify(source));
test('Apparition display/class spelling cannot replace its Ghostly source ID', () => {
  assert.throws(() => verify(source.replace(/(card\('apparition','[^']*',)'[^']*'/,
    "$1'Apparition'")), /sourceId for apparition/);
});
test('another registered ID is still rejected when assigned to the wrong class', () => {
  assert.throws(() => verify(source.replace(/(card\('blind','[^']*',)'Blind'/,
    "$1'Trip'")), /sourceId for blind/);
});
