// Exact outer replay adapter for this presentation-only slice. Live tests load
// current production modules; original historical witnesses stay immutable.
import assert from 'node:assert/strict';
import {existsSync, readFileSync, rmSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';

const normalize = source => source.replaceAll('\r\n', '\n');
const hash = source => createHash('sha256').update(source).digest('hex');
const bytes = normalize(readFileSync(new URL('../fixtures/battle-life-source-layer.json', import.meta.url), 'utf8'));
assert.equal(hash(bytes), 'd068b1345c2a1a7761bfc61043453d7fa7d2a6f88d8e388aa4136b4e2acb317d', 'complete battle-life outer source identity');
export const battleLifeSourceLayer = JSON.parse(bytes);
assert.equal(battleLifeSourceLayer.schemaVersion, 1);
assert.equal(battleLifeSourceLayer.baseCommit, 'd4c4b25594798f9d2f4fc6b66a061532c2b71595');
assert.equal(battleLifeSourceLayer.reviewedHead, '45ee2b479ee7576665eaffab81cac8be488906d9');
for (const [path, binding] of Object.entries(battleLifeSourceLayer.files)) {
  assert.match(path, /^(?:src\/lua\/[^/]+\.lua|scripts\/[^/]+\.mjs|config\/[^/]+\.json|data\/presentation\/ui_theme\.json|tests\/ui-layout\.test\.mjs)$/);
  assert.match(binding.afterSha256, /^[a-f0-9]{64}$/);
  assert.ok(binding.beforeSha256 === null || /^[a-f0-9]{64}$/.test(binding.beforeSha256));
  assert.ok(Array.isArray(binding.hunks));
  if (binding.beforeSha256 === null) assert.deepEqual(binding.hunks, [], 'genuinely new module has no historical source');
}

export function preBattleLifeSource(path, source) {
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
  const targets = [];
  for (const path of battleLifeAddedPaths) {
    const target = join(directory, path);
    if (!existsSync(target)) continue;
    assert.equal(hash(normalize(readFileSync(target, 'utf8'))), battleLifeSourceLayer.files[path].afterSha256,
      'unreviewed battle-life added module destination: ' + path);
    targets.push(target);
  }
  return () => { for (const target of targets) rmSync(target); };
}
