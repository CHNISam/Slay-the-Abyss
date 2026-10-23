import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { tmpdir } from 'node:os';
import { candidateScriptFiles } from '../scripts/native-candidate-scripts.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';

const generated = ['abyss_data', 'abyss_map_layout', 'abyss_narrative', 'abyss_presentation', 'abyss_theme'];
function fixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-native-scripts-'));
  const source = join(root, 'src'), build = join(root, 'build');
  mkdirSync(source); mkdirSync(build);
  writeFileSync(join(source, 'abyss_ui.lua'), 'return {}');
  for (const name of generated) writeFileSync(join(build, `${name}.lua`), 'return {}');
  try { run(source, build); } finally {
    const inside = relative(resolve(tmpdir()), resolve(root));
    assert(!isAbsolute(inside) && !inside.startsWith('..') && inside.startsWith('abyss-native-scripts-'));
    rmSync(root, { recursive: true, force: true });
  }
}

test('native package excludes generated test fixtures, stale modules and UI serialization helpers', () => fixture((source, build) => {
  for (const name of ['sts1_unknown_vectors', 'stale_test', 'abyss_ui_layout', 'abyss_ui_templates', 'abyss_map_controls'])
    writeFileSync(join(build, `${name}.lua`), 'error("must never ship")');
  assert.deepEqual(candidateScriptFiles(source, build).map(item => item.name).sort(), [...generated, 'abyss_ui'].sort());
}));

test('native package preflight rejects missing generated modules and name collisions', () => fixture((source, build) => {
  writeFileSync(join(source, 'abyss_theme.lua'), 'return {}');
  assert.throws(() => candidateScriptFiles(source, build), /Duplicate game module: abyss_theme/);
  rmSync(join(source, 'abyss_theme.lua'));
  rmSync(join(build, 'abyss_theme.lua'));
  assert.throws(() => candidateScriptFiles(source, build), /ENOENT/);
}));

test('ordinary native package declares the UI BGM parameter as boolean false', () => fixture((source, build) => {
  const scripts = candidateScriptFiles(source, build);
  assert.deepEqual(scripts.find(item => item.name === 'abyss_ui').variables,
    [{ name: 'nativeBgmEnabled', type: 'boolean', value: false }]);
  for (const item of scripts.filter(item => item.name !== 'abyss_ui')) assert.equal(item.variables, undefined);
}));

test('actual game module set includes current AI and all generated runtime dependencies, never the W1 fixture', () => fixture((_, build) => {
  buildUI(build);
  buildLuaData('data', join(build, 'abyss_data.lua'));
  writeFileSync(join(build, 'sts1_unknown_vectors.lua'), 'error("test fixture")');
  const names = candidateScriptFiles('src/lua', build).map(item => item.name);
  for (const name of ['abyss_ui', 'abyss_jaw_worm_ai', 'abyss_gremlin_nob_ai', 'abyss_blue_slaver_ai', 'abyss_acid_slime_s_ai', 'abyss_sentry_ai', 'abyss_enemy_ai', ...generated]) assert(names.includes(name), name);
  assert(!names.includes('sts1_unknown_vectors'));
  assert.equal(new Set(names).size, names.length);
}));
