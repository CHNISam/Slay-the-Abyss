import {prepareMonsterArt} from '../scripts/monster-art.mjs';
import {portraitInputs} from '../scripts/official-portraits.mjs';
import {readyArtInputs,readyArtSourceInputs} from '../scripts/art/ready-card-runtime.mjs';
import {backgroundInputs} from '../scripts/official-background.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { copyFileSync, cpSync, existsSync, linkSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { buildUI } from '../scripts/build-ui.mjs';

const inputs = ['cards.json', 'statuses.json', 'enemies.json', 'relics.json', 'potions.json', 'rules.json',
  'presentation/native-monster-art.json', 'presentation/ui_theme.json', 'presentation/traveler.zh-CN.json', 'presentation/narrative.zh-CN.json'];
const outputs = ['abyss_theme.lua', 'map-ui.json', 'abyss_map_layout.lua', 'abyss_map_controls.lua',
  'abyss_narrative.lua', 'abyss_presentation.lua', 'battle-ui.json', 'game-ui.json', 'abyss_ui_layout.lua',
  'game-ui-templates.json', 'abyss_ui_templates.lua', 'abyss_menu_background_asset.lua',
  'abyss_ready_card_binding.lua','abyss_ready_card_assets.lua','abyss_traveler_portrait_assets.lua','abyss_monster_art_data.lua','abyss_art_features.lua','abyss_monster_actor_binding.lua','art-render-v2.json'];
function fixture(action, cli = false) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-ui-input-'));
  try {
    // Every case owns fresh mutable data/output. Only CLI cases need a script
    // tree; the in-process cases use the real already-imported production code.
    cpSync(resolve('data'), join(root, 'data'), { recursive: true });
    for(const file of [...backgroundInputs,...readyArtSourceInputs(),...portraitInputs]){mkdirSync(dirname(join(root,file)),{recursive:true});copyFileSync(resolve(file),join(root,file));}
    for(const file of prepareMonsterArt().inputPaths){mkdirSync(dirname(join(root,file)),{recursive:true});cpSync(resolve(file),join(root,file));}
    for (const file of ['package.json', 'package-lock.json', '.release-please-manifest.json', 'CHANGELOG.md'])
      copyFileSync(resolve(file), join(root, file));
    if (cli) cpSync(resolve('scripts'), join(root, 'scripts'), { recursive: true });
    mkdirSync(join(root, 'tools'));
    copyFileSync(resolve('tools/render_traveler_cards.py'), join(root, 'tools/render_traveler_cards.py'));
    mkdirSync(join(root, 'out'));
    return action(root);
  } finally { rmSync(root, { recursive: true, force: true }); }
}
const cliFixture = action => fixture(action, true);
function build(root) {
  const cwd = process.cwd();
  try { process.chdir(root); buildUI('out'); } finally { process.chdir(cwd); }
}
for (const mode of ['hardlink', 'symlink']) for (const input of inputs) for (const output of [...outputs,'art-performance.json']) {
  test(`UI build rejects ${output} ${mode} to ${input} before writing`, t => fixture(root => {
    const source = join(root, 'data', input), target = join(root, 'out', output);
    try { if (mode === 'hardlink') linkSync(source, target); else symlinkSync(source, target, 'file'); }
    catch (error) {
      if (mode === 'symlink' && ['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return; }
      throw error;
    }
    const before = inputs.map(file => readFileSync(join(root, 'data', file)));
    let error;
    try { build(root); } catch (caught) { error = caught; }
    inputs.forEach((file, index) => assert.equal(readFileSync(join(root, 'data', file)).equals(before[index]), true, `${file} changed`));
    assert.match(error?.message ?? '', /Output must not overwrite an input file/);
    assert.deepEqual(readdirSync(join(root, 'out')), [output], 'must not leave partial generated files');
  }));
}
test('UI build creates and replaces all normal generated outputs without touching inputs', () => fixture(root => {
  const before = inputs.map(file => readFileSync(join(root, 'data', file)));
  build(root);
  assert.deepEqual(readdirSync(join(root, 'out')).sort(), [...outputs].sort());
  const first = outputs.map(file => readFileSync(join(root, 'out', file)));
  build(root);
  outputs.forEach((file, index) => assert.deepEqual(readFileSync(join(root, 'out', file)), first[index]));
  inputs.forEach((file, index) => assert.deepEqual(readFileSync(join(root, 'data', file)), before[index]));
}));
for (const mode of ['hardlink', 'symlink']) test(`UI build retains legitimate ${mode} generated-output behavior`, t => fixture(root => {
  const backing = join(root, 'generated.lua'), target = join(root, 'out', 'abyss_narrative.lua');
  writeFileSync(backing, 'old generated output');
  try { if (mode === 'hardlink') linkSync(backing, target); else symlinkSync(backing, target, 'file'); }
  catch (error) { if (mode === 'symlink' && ['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return; } throw error; }
  build(root);
  assert.match(readFileSync(backing, 'utf8'), /^-- Generated from the approved narrative/);
  assert.deepEqual(readFileSync(target), readFileSync(backing));
}));

test('explicit zero-art UI CLI builds without npm dependencies and preserves zero-art fallback', () => cliFixture(root => {
  assert.equal(existsSync(join(root, 'node_modules')), false, 'fixture must not borrow installed npm dependencies');
  const entry = spawnSync(process.execPath, ['--input-type=module', '-e',
    "await import('./scripts/build-native-candidate.mjs'); const {verifyNativeCardArtReceipt}=await import('./scripts/card-art-samples.mjs'); verifyNativeCardArtReceipt(undefined);"],
    { cwd: root, encoding: 'utf8' });
  assert.equal(entry.status, 0, entry.stderr);
  const before = inputs.map(file => readFileSync(join(root, 'data', file)));
  const result = spawnSync(process.execPath, ['scripts/build-ui.mjs', 'out', '--no-ready-card-art'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Native battle UI and Traveler display module built/);
  assert.deepEqual(readdirSync(join(root, 'out')).sort(), [...outputs].sort());
  assert.doesNotMatch(readFileSync(join(root, 'out/game-ui.json'), 'utf8'), /"artSamples"/);
  assert.doesNotMatch(readFileSync(join(root, 'out/abyss_presentation.lua'), 'utf8'), /\["nativeArt"\]/);
  inputs.forEach((file, index) => assert.deepEqual(readFileSync(join(root, 'data', file)), before[index]));
}));

for (const mode of ['hardlink', 'symlink']) test(`UI CLI rejects narrative ${mode} without success output`, t => cliFixture(root => {
  const source = join(root, 'data/presentation/narrative.zh-CN.json');
  const target = join(root, 'out/abyss_narrative.lua');
  try { if (mode === 'hardlink') linkSync(source, target); else symlinkSync(source, target, 'file'); }
  catch (error) { if (mode === 'symlink' && ['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return; } throw error; }
  const before = readFileSync(source);
  const result = spawnSync(process.execPath, ['scripts/build-ui.mjs', 'out'], { cwd: root, encoding: 'utf8' });
  assert.equal(readFileSync(source).equals(before), true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Output must not overwrite an input file/);
  assert.doesNotMatch(result.stdout, /built/);
}));

test('UI rejection preserves existing outputs when the final batch target aliases an input', () => fixture(root => {
  const last = outputs.at(-1);
  for (const file of outputs.slice(0, -1)) writeFileSync(join(root, 'out', file), `existing ${file}`);
  const input = join(root, 'data/presentation/narrative.zh-CN.json');
  const before = readFileSync(input);
  linkSync(input, join(root, 'out', last));
  assert.throws(() => build(root), /Output must not overwrite an input file/);
  assert.equal(readFileSync(input).equals(before), true);
  for (const file of outputs.slice(0, -1)) assert.equal(readFileSync(join(root, 'out', file), 'utf8'), `existing ${file}`);
}));

test('UI CLI protects the imported module-relative theme when working in a different data directory', () => cliFixture(root => {
  const cwd = join(root, 'other');
  mkdirSync(cwd); cpSync(join(root, 'data'), join(cwd, 'data'), { recursive: true });
  cpSync(join(root,'art'),join(cwd,'art'),{recursive:true});
  for (const file of ['package.json', 'package-lock.json', '.release-please-manifest.json', 'CHANGELOG.md'])
    copyFileSync(join(root, file), join(cwd, file));
  cpSync(join(root, 'tools'), join(cwd, 'tools'), { recursive: true }); mkdirSync(join(cwd, 'out'));
  const input = join(root, 'data/presentation/ui_theme.json');
  const before = readFileSync(input);
  linkSync(input, join(cwd, 'out/abyss_ui_templates.lua'));
  const result = spawnSync(process.execPath, [join(root, 'scripts/build-ui.mjs'), 'out'], { cwd, encoding: 'utf8' });
  assert.equal(readFileSync(input).equals(before), true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Output must not overwrite an input file/);
  assert.deepEqual(readdirSync(join(cwd, 'out')), ['abyss_ui_templates.lua']);
}));

for(const input of [...backgroundInputs,...readyArtInputs,...portraitInputs])test(`UI background output cannot overwrite frozen runtime input ${input}`,()=>fixture(root=>{
 const source=join(root,input),before=readFileSync(source);linkSync(source,join(root,'out/abyss_menu_background_asset.lua'));
 assert.throws(()=>build(root),/Output must not overwrite an input file/);assert.deepEqual(readFileSync(source),before);
 assert.deepEqual(readdirSync(join(root,'out')),['abyss_menu_background_asset.lua']);
}));

test('optional compact metadata output cannot overwrite an input even when compact mode is off',()=>fixture(root=>{
 const input=join(root,'data/presentation/narrative.zh-CN.json'),before=readFileSync(input);
 linkSync(input,join(root,'out/art-performance.json'));
 assert.throws(()=>build(root),/Output must not overwrite an input file/);
 assert.deepEqual(readFileSync(input),before);
 assert.deepEqual(readdirSync(join(root,'out')),['art-performance.json']);
}));
