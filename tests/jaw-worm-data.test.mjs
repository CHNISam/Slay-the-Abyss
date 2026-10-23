import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

test('production Jaw Worm declares sourced A0 moves and a stateful decision policy', () => {
  const data = loadContent('data');
  const enemy = data.enemies.enemies.find(e => e.id === 'jaw_worm');
  assert.equal(enemy.ai?.kind, 'jaw_worm');
  assert.deepEqual(enemy.hpRange, { min: 40, max: 44 });
  assert.deepEqual(validateContent(data), []);
});

for (const [name, change, expected] of [
  ['unknown intent', a => a.chompIntent = 'missing', /chompIntent/],
  ['inactive Thrash', a => a.thrashIntent = 'jaw_worm_3', /thrashIntent/],
  ['duplicated attacks', a => a.thrashIntent = a.chompIntent, /distinct/],
  ['unknown parameter', a => a.guess = true, /guess/],
  ['zero roll range', a => a.rollRange = 0, /rollRange/],
  ['fractional cutoff', a => a.chompCutoff = 24.5, /chompCutoff/],
  ['reversed cutoffs', a => a.chompCutoff = 56, /cutoff order/],
  ['cutoff beyond range', a => a.thrashCutoff = 101, /cutoff order/],
  ['missing probability', a => delete a.bellowAfterChomp, /bellowAfterChomp/],
  ['negative probability', a => a.chompAfterTwoThrashes = -0.1, /chompAfterTwoThrashes/],
  ['probability over one', a => a.chompAfterBellow = 1.01, /chompAfterBellow/],
  ['nonfinite probability', a => a.chompAfterBellow = NaN, /chompAfterBellow/],
]) {
  test(`rejects Jaw Worm ${name}`, () => {
    const data = loadContent('data');
    const enemy = data.enemies.enemies.find(e => e.id === 'jaw_worm');
    change(enemy.ai);
    assert.match(validateContent(data).join('\n'), expected);
  });
}
