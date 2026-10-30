import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nativeEnemyThemeLayer as layer, preNativeEnemyThemeSource as prior} from './helpers/native-enemy-theme-inverse.mjs';
import {preBattleLifeSource} from './helpers/battle-life-source-inverse.mjs';
import {requirePr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
const hash = source => createHash('sha256').update(source).digest('hex');
const live = readFileSync(layer.path, 'utf8').replaceAll('\r\n', '\n');
test('native enemy outer inverse exactly recovers prior complete theme without rewriting historical witnesses', () => {
  assert.equal(hash(live), layer.afterSha256);
  const before = prior(layer.path, live);
  assert.equal(hash(before), layer.beforeSha256);
  assert.equal(before.replace(layer.before, layer.after), live);
  assert.equal(prior(layer.path, live.replaceAll('\n', '\r\n')), before);
  assert.equal(prior(layer.path, before), before);
  requirePr323Source(layer.path, live);
});
test('partial, duplicated, moved and unrelated theme drift cannot acquire replay permission', () => {
  const moved = live.replace(layer.after, '').replace('  "version":', layer.after + '\n  "version":');
  for (const mutant of [
    live.replace('"wizard_gremlin": 112024', '"wizard_gremlin": 112034'),
    live.replace(layer.after, layer.after + '\n' + layer.after),
    live.replace('      "byrd": 112065,\n', ''), moved,
    live.replace('"body": 18', '"body": 19'), live + '\n', live.slice(1),
  ]) {
    assert.notEqual(mutant, live);
    assert.equal(prior(layer.path, mutant), mutant);
    assert.equal(preBattleLifeSource(layer.path, mutant), mutant);
    assert.throws(() => requirePr323Source(layer.path, mutant), /unreviewed integrated/);
  }
  assert.equal(prior('other.json', live), live);
  assert.equal(prior(layer.path, null), null);
});
