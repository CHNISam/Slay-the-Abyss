import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';

for (const [name, change, expected] of [
  ['nonpositive initial threshold', e => e.ai.initialThreshold = 0, /initialThreshold/],
  ['nonpositive threshold increment', e => e.ai.thresholdIncrement = 0, /thresholdIncrement/],
  ['fractional shift Block', e => e.ai.shiftBlock = 20.5, /shiftBlock/],
  ['unknown guardian field', e => e.ai.sleepTurns = 3, /sleepTurns/],
  ['empty offense', e => e.ai.offenseCycle = [], /offenseCycle/],
  ['empty defense', e => e.ai.defenseCycle = [], /defenseCycle/],
  ['unknown offense reference', e => e.ai.offenseCycle[0] = 'missing', /offenseCycle/],
  ['unknown defense reference', e => e.ai.defenseCycle[0] = 'missing', /defenseCycle/],
  ['return outside offense', e => e.ai.returnIntent = 'guardian_5', /returnIntent/],
  ['unknown return', e => e.ai.returnIntent = 'missing', /returnIntent/]
]) {
  test(`Guardian configuration rejects ${name}`, () => {
    const data = loadContent('data');
    change(data.enemies.enemies.find(e => e.id === 'guardian'));
    assert.match(validateContent(data).join('\n'), expected);
  });
}

for (const id of ['mode_shift', 'sharp_hide']) {
  test(`Guardian configuration requires ${id} status metadata`, () => {
    const data = loadContent('data');
    data.statuses.statuses = data.statuses.statuses.filter(s => s.id !== id);
    assert.match(validateContent(data).join('\n'), new RegExp(`unknown statuses ID ${id}`));
  });
}
