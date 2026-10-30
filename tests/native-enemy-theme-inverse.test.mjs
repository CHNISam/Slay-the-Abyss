import {prePotionManageSource} from './helpers/potion-manage-source-inverse.mjs';
import {preCombatRelicsHudSource} from './helpers/combat-relics-hud-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nativeEnemyThemeLayer as layer, nativeEnemyThemeComposedLayer as composed, preNativeEnemyThemeSource as prior} from './helpers/native-enemy-theme-inverse.mjs';
import {relicCompletionInverse, preRelicCompletionSource, requireRelicCompletionSource} from './helpers/relic-completion-inverse.mjs';
import {preMapPathA11ySource} from './helpers/map-path-a11y-inverse.mjs';
import {preBattleLifeSource} from './helpers/battle-life-source-inverse.mjs';
import {requirePr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
const hash = source => createHash('sha256').update(source).digest('hex');
const live = prePotionManageSource(layer.path,readFileSync(layer.path, 'utf8').replaceAll('\r\n', '\n'));
test('native enemy outer inverse exactly recovers prior complete theme without rewriting historical witnesses', () => {
  assert.equal(hash(live), composed.afterSha256);
  const before = prior(layer.path, live);
  assert.equal(hash(before), composed.beforeSha256);
  assert.equal(before.replace(layer.before, layer.after), live);
  assert.equal(prior(layer.path, live.replaceAll('\n', '\r\n')), before);
  assert.equal(prior(layer.path, before), before);
  const base = preRelicCompletionSource(layer.path, before);
  assert.equal(hash(base), layer.beforeSha256);
  const originalNative = base.replace(layer.before, layer.after);
  assert.equal(hash(originalNative), layer.afterSha256, 'original complete native witness remains accepted');
  assert.equal(prior(layer.path, originalNative), base);
  assert.equal(prior(layer.path, originalNative.replaceAll('\n', '\r\n')), base);
  const relic = relicCompletionInverse.files[layer.path];
  assert.equal(composed.beforeSha256, relic.afterSha256);
  assert.equal(hash(preRelicCompletionSource(layer.path, live)), relic.beforeSha256, 'direct relic callers compose the exact native inverse first');
  requireRelicCompletionSource(layer.path, live);
  requirePr323Source(layer.path, live);
});
test('partial, duplicated, moved and unrelated theme drift cannot acquire replay permission', () => {
  const moved = live.replace(layer.after, '').replace('  "version":', layer.after + '\n  "version":');
  for (const mutant of [
    live.replace('"wizard_gremlin": 112024', '"wizard_gremlin": 112034'),
    live.replace(layer.after, layer.after + '\n' + layer.after),
    live.replace('      "byrd": 112065,\n', ''), moved,
    live.replace('"body": 18', '"body": 19'), live + '\n', live.slice(1),
    live.replace('"bottled_tornado": {"id":102028', '"bottled_tornado": {"id":102029'),
    live.replace('"buffer": {"id":102036', '"buffer": {"id":102037'),
  ]) {
    assert.notEqual(mutant, live);
    assert.equal(prior(layer.path, mutant), mutant);
    assert.equal(preBattleLifeSource(layer.path, mutant), mutant);
    assert.equal(preRelicCompletionSource(layer.path, mutant), mutant);
    assert.throws(() => requireRelicCompletionSource(layer.path, mutant), /unreviewed relic completion/);
    assert.throws(() => requirePr323Source(layer.path, mutant), /unreviewed integrated/);
  }
  assert.equal(prior('other.json', live), live);
  assert.equal(prior(layer.path, null), null);
});
