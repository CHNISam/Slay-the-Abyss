import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { defaultNativeCardArt } from '../scripts/build-native-audio-game.mjs';
import { prepareNativeCardArt, nativeCardArtBuildReceipt, verifyNativeCardArtReceipt } from '../scripts/card-art-samples.mjs';

test('normal build art defaults consume frozen two-card inputs in exactly one static pool', t => {
  const root = process.cwd();
  mkdirSync(join(root, 'build'), { recursive: true });
  const directory = mkdtempSync(join(root, 'build/default-card-art-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const result = spawnSync(process.execPath, ['scripts/build-ui.mjs', directory,
    `--native-card-art-registry=${defaultNativeCardArt.registry}`, '--native-card-art-host=battlePanel/card1'],
    { cwd: root, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr);
  const registry = JSON.parse(readFileSync(resolve(root, defaultNativeCardArt.registry)));
  assert(registry.sourceInputs.every(input => input.path.startsWith('art/cards/traveler-geo/')));
  const candidate = prepareNativeCardArt({ registry: defaultNativeCardArt.registry, hosts: ['battlePanel/card1'] }, { root });
  const receipt = nativeCardArtBuildReceipt(candidate, { root, directory });
  assert.deepEqual(Object.keys(receipt.sources).sort(), ['cleave', 'heavy_blade']);
  assert.equal(receipt.sources.cleave.images, 2657);
  assert.equal(receipt.sources.heavy_blade.images, 2043);
  assert.equal(receipt.staticPools, 1);
  assert.equal(receipt.staticAddedControls, 2703);
  assert.equal(receipt.deckTemplateEnabled, false);
  assert.equal(receipt.performance, 'not_measured');
  verifyNativeCardArtReceipt(receipt, { root });
});
