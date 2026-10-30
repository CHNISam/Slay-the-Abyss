import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { legacyNativeCardArt } from '../scripts/build-native-audio-game.mjs';
import { prepareNativeCardArt, nativeCardArtBuildReceipt, verifyNativeCardArtReceipt } from '../scripts/card-art-samples.mjs';

test('explicit legacy art option consumes frozen two-card inputs in exactly one static pool', t => {
  const root = process.cwd();
  mkdirSync(join(root, 'build'), { recursive: true });
  const directory = mkdtempSync(join(root, 'build/default-card-art-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const result = spawnSync(process.execPath, ['scripts/build-ui.mjs', directory,
    `--native-card-art-registry=${legacyNativeCardArt.registry}`, '--native-card-art-host=battlePanel/card1'],
    { cwd: root, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr);
  const registry = JSON.parse(readFileSync(resolve(root, legacyNativeCardArt.registry)));
  assert(registry.sourceInputs.every(input => input.path.startsWith('art/cards/traveler-geo/')));
  const candidate = prepareNativeCardArt({ registry: legacyNativeCardArt.registry, hosts: ['battlePanel/card1'] }, { root });
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


test('normal UI build keeps all75 assets lazy and all card contexts dynamically eligible', t => {
  const root=process.cwd();mkdirSync(join(root,'build'),{recursive:true});
  const directory=mkdtempSync(join(root,'build/default-ready-art-'));
  t.after(()=>rmSync(directory,{recursive:true,force:true}));
  const result=spawnSync(process.execPath,['scripts/build-ui.mjs',directory],{cwd:root,encoding:'utf8',timeout:60000});
  assert.equal(result.status,0,result.stderr);
  const assets=readFileSync(join(directory,'abyss_ready_card_assets.lua'),'utf8');
  assert.equal((assets.match(/\["runtime"\]=true/g)??[]).length,75);
  assert.equal((assets.match(/\["rectangleEncoding"\]=/g)??[]).length,72);
  const holders=[];
  function visit(node){if(node.name==='artSamples')holders.push(node);for(const child of node.children??node.controls??[])visit(child);}
  visit(JSON.parse(readFileSync(join(directory,'game-ui.json'))));
  for(const template of JSON.parse(readFileSync(join(directory,'game-ui-templates.json'))))visit(template);
  assert.equal(holders.length,39);for(const holder of holders)assert.deepEqual(holder.children,[]);
  assert.equal(existsSync(join(directory,'native-card-art-receipt.json')),false,'normal build must not silently select the legacy static pool');
});
