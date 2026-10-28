import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildLuaData, toLua } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';

// Existing two-slot recipe, not frozen artwork provenance or real-source proof.
const row = (image = 100003) => ({ image, position: [1.125, -2.25], size: [3.5, 4.75],
  anchorMin: [.5, .5], anchorMax: [.5, .5], pivot: [.5, .5], scale: [1, 1],
  rotation: [23.125, -45.25, 9.75], colour: [12, 34, 56, 78],
  imageType: image === 100003 ? 'stretch' : 'basic' });
const registry = () => ({ schemaVersion: 2, editorCommit: '103025f9095d8089e3f9bf097f4d0c5fe039d546',
  canvas: [144, 64], assets: {
    cleave: { cardId: 'cleave', luaSha256: 'a'.repeat(64), jsonSha256: 'b'.repeat(64), slots: [row(), row(106057)] },
    heavy_blade: { cardId: 'heavy_blade', luaSha256: 'c'.repeat(64), jsonSha256: 'd'.repeat(64), slots: [row(106056)] },
  } });

function candidate(fn) {
  const output = mkdtempSync(join(tmpdir(), 'abyss-native-art-ending-'));
  try {
    buildLuaData('data', join(output, 'abyss_data.lua'));
    buildUI(output, undefined, { nativeCardArt: { registry: registry(), hosts: ['battlePanel/card1'] } });
    const pools = [];
    function visit(node, path = '') {
      const current = path + '/' + (node.name ?? '');
      if (node.name === 'artSamples') pools.push(current);
      for (const child of node.children ?? node.controls ?? []) visit(child, current);
    }
    visit(JSON.parse(readFileSync(join(output, 'game-ui.json'))));
    assert.equal(pools.length, 1);
    assert(pools[0].endsWith('/battlePanel/card1/artSamples'));
    const receipt = JSON.parse(readFileSync(join(output, 'native-card-art-receipt.json')));
    assert.equal(receipt.staticPools, 1); assert.equal(receipt.capacity, 2);
    assert.equal(receipt.staticAddedControls, 4); assert.equal(receipt.deckTemplateEnabled, false);
    return fn(output);
  } finally {
    rmSync(output, { recursive: true, force: true });
  }
}

function runEnding(output, preload = '') {
  const bootstrap = join(output, 'ending.lua');
  const path = `${output.replaceAll('\\', '/')}/?.lua;src/lua/?.lua;`;
  writeFileSync(bootstrap, `package.path=${toLua(path)}..package.path\n${preload}
dofile('tests/lua/support/native_card_art_ending.lua')\n`);
  return runLua(bootstrap); // Existing default 30 seconds; no runner override.
}

test('enabled native card art clears through the real Heart Proceed and true-ending host', () => candidate(output => {
  const result = runEnding(output);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /NATIVE_ART_ENDING_TRANSITION_PASS 1 focused integration/);
  console.log(result.stdout.trim());
}));

test('Heart ending integration rejects a missing native card-art transition clear', () => candidate(output => {
  const source = readFileSync('src/lua/abyss_battle_card_view.lua', 'utf8');
  const before = 'if not id then CardDisplay.clearNativeArt(box);return end';
  assert.equal(source.split(before).length, 2, 'exactly one in-memory mutation target');
  const mutated = source.replace(before, 'if not id then return end');
  const preload = `package.preload['abyss_battle_card_view']=function()
return assert(load(${toLua(mutated)},'@in-memory-no-transition-clear'))()end\n`;
  const result = runEnding(output, preload);
  assert.notEqual(result.status, 0, 'missing transition clear must fail');
  assert.match(result.stdout, /PASS art: one real generated host/);
  assert.match(result.stderr, /transition must explicitly clear bound art/);
  assert.doesNotMatch(result.stdout, /NATIVE_ART_ENDING_TRANSITION_PASS/);
  assert.equal(readFileSync('src/lua/abyss_battle_card_view.lua', 'utf8'), source);
  console.log(`Native art ending negative control caught: ${result.stderr.split('\n')[0]}`);
}));
