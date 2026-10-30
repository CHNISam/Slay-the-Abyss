import {preCombatVfxUpgradeSource} from './combat-vfx-upgrade-inverse.mjs';
import {prepareArtFeatureRetirement} from './art-feature-source-inverse.mjs';
import {prepareRound3CatalogModuleRetirement} from './round3-catalog-source-inverse.mjs';
import {preBackgroundSource,prepareBackgroundRetirement} from './official-background-source-inverse.mjs';
import {preNativeEnemyThemeSource} from './native-enemy-theme-inverse.mjs';
import {preRelicRound2CompositionSource} from './relic-round2-composition.mjs';
import {preRound2CanPlaySource} from './round2-can-play-source-inverse.mjs';
import {preRound2UiSource,prepareRound2UiModuleRetirement} from './round2-ui-source-inverse.mjs';
// Exact outer replay adapter for this presentation-only slice. Live tests load
// current production modules; original historical witnesses stay immutable.
import assert from 'node:assert/strict';
import {preCiLuaCalibrationSource} from './ci-lua-calibration-inverse.mjs';
import {existsSync, readFileSync, rmSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {preRelicCompletionSource,prepareRelicCompletionModuleRetirement} from './relic-completion-inverse.mjs';

const normalize = source => source.replaceAll('\r\n', '\n');
const hash = source => createHash('sha256').update(source).digest('hex');
const bytes = normalize(readFileSync(new URL('../fixtures/battle-life-source-layer.json', import.meta.url), 'utf8'));
assert.equal(hash(bytes), '4d1e5af98f2c8fb31fa1e78d5b590636c3a9658e668d08d5dbac36667b19b8ad', 'complete battle-life outer source identity');
export const battleLifeSourceLayer = JSON.parse(bytes);
assert.equal(battleLifeSourceLayer.schemaVersion, 1);
assert.equal(battleLifeSourceLayer.baseCommit, 'd4c4b25594798f9d2f4fc6b66a061532c2b71595');
assert.equal(battleLifeSourceLayer.reviewedHead, 'd2c1148c4f20d16474edf688449e1daf269dc979');
for (const [path, binding] of Object.entries(battleLifeSourceLayer.files)) {
  assert.match(path, /^(?:src\/lua\/[^/]+\.lua|scripts\/[^/]+\.mjs|config\/[^/]+\.json|data\/presentation\/ui_theme\.json|tests\/ui-layout\.test\.mjs)$/);
  assert.match(binding.afterSha256, /^[a-f0-9]{64}$/);
  assert.ok(binding.beforeSha256 === null || /^[a-f0-9]{64}$/.test(binding.beforeSha256));
  assert.ok(Array.isArray(binding.hunks));
  if (binding.beforeSha256 === null) assert.deepEqual(binding.hunks, [], 'genuinely new module has no historical source');
}

export function preBattleLifeOuterSource(path, source) {
  source=preCombatVfxUpgradeSource(path,source);
  source = preRelicRound2CompositionSource(path,source,'relic');
  source = preRound2UiSource(path,source);
  source = preNativeEnemyThemeSource(path,preBackgroundSource(path,source));
  source = preCiLuaCalibrationSource(path, source);
  source = preRound2CanPlaySource(path, source);
  return preRelicCompletionSource(path,source);
}

export function preBattleLifeSource(path, source) {
  source = preBattleLifeOuterSource(path, source);
  const binding = battleLifeSourceLayer.files[path];
  if (!binding || typeof source !== 'string') return source;
  const normalized = normalize(source);
  // Partial/foreign/future source must still reach every unchanged strict guard.
  if (hash(normalized) !== binding.afterSha256) return source;
  if (binding.beforeSha256 === null) return null;
  const lines = normalized.split('\n');
  for (const hunk of [...binding.hunks].reverse()) {
    assert.deepEqual(lines.slice(hunk.at, hunk.at + hunk.after.length), hunk.after,
      'exact battle-life inverse hunk and position: ' + path);
    lines.splice(hunk.at, hunk.after.length, ...hunk.before);
  }
  const previous = lines.join('\n');
  assert.equal(hash(previous), binding.beforeSha256, 'complete pre-battle-life source recovered: ' + path);
  return previous;
}

export const battleLifeAddedPaths = Object.freeze(Object.entries(battleLifeSourceLayer.files)
  .filter(([, binding]) => binding.beforeSha256 === null).map(([path]) => path));

// Validate the complete new-module destination inventory before any caller
// writes/deletes. Return a deferred cleanup so older materializers keep their
// own full source/destination validation and exact historical ownership.
export function prepareBattleLifeModuleRetirement(directory, {sourceRoot = process.cwd()} = {}) {
  assert.notEqual(resolve(directory), resolve(sourceRoot), 'battle-life retirement requires a separate historical destination');
  const retireBackground=prepareBackgroundRetirement(directory,{sourceRoot});
  const retireRound2=prepareRound2UiModuleRetirement(directory,{sourceRoot});
  const retireRound3=prepareRound3CatalogModuleRetirement(directory,{sourceRoot});
  const retireRelics=prepareRelicCompletionModuleRetirement(directory,{sourceRoot});
  const targets = [];
  for (const path of battleLifeAddedPaths) {
    const target = join(directory, path);
    if (!existsSync(target)) continue;
    assert.equal(hash(normalize(preRelicCompletionSource(path,readFileSync(target, 'utf8')))), battleLifeSourceLayer.files[path].afterSha256,
      'unreviewed battle-life added module destination: ' + path);
    targets.push(target);
  }
  return () => {
    // Revalidate both newest owners before any composed historical deletion.
    prepareArtFeatureRetirement(directory,{sourceRoot});
    retireRound3();
    for (const target of targets) rmSync(target); retireRound2(); retireBackground();retireRelics();
  };
}
