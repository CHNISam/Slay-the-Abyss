import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, linkSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';
import { buildUiTheme } from '../scripts/build-ui-theme.mjs';
import { contentFiles } from '../scripts/validate-data.mjs';

const inputs = ['presentation/ui_theme.json', ...contentFiles.map(file => `${file}.json`)];
function temporary(action) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-theme-protection-'));
  try {
    const data = join(root, 'data');
    cpSync('data', data, { recursive: true });
    return action(root, data, join(data, inputs[0]));
  } finally { rmSync(root, { recursive: true, force: true }); }
}

for (const input of inputs) {
  for (const mode of ['direct', 'relative', 'symlink', 'hardlink']) {
    test(`theme export rejects ${mode} alias of ${input} without changing any input`, t => temporary((root, data, theme) => {
      const target = join(data, input);
      const output = mode === 'direct' ? target : mode === 'relative' ? relative(process.cwd(), target) : join(root, 'output.lua');
      const before = inputs.map(file => readFileSync(join(data, file)));
      try {
        if (mode === 'symlink') symlinkSync(target, output);
        if (mode === 'hardlink') linkSync(target, output);
      } catch (error) {
        if (mode === 'symlink' && ['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return; }
        throw error;
      }
      let error;
      try { buildUiTheme(theme, data, output); } catch (caught) { error = caught; }
      for (let index = 0; index < inputs.length; index++) {
        assert.equal(readFileSync(join(data, inputs[index])).equals(before[index]), true, `${inputs[index]} must remain unchanged`);
      }
      assert.match(error?.message ?? '', /Output must not overwrite an input file/);
    }));
  }
}

test('theme export still creates and replaces an ordinary output deterministically', () => temporary((root, data, theme) => {
  const before = inputs.map(file => readFileSync(join(data, file)));
  const output = join(root, 'generated', 'theme.lua');
  const first = buildUiTheme(theme, data, output);
  assert.match(first, /^-- Generated/);
  assert.equal(readFileSync(output, 'utf8'), first);
  assert.equal(buildUiTheme(theme, data, output), first);
  assert.equal(readFileSync(output, 'utf8'), first);
  for (let index = 0; index < inputs.length; index++) assert.equal(readFileSync(join(data, inputs[index])).equals(before[index]), true);
}));

function makeSymlink(t, target, output, type) {
  try { symlinkSync(target, output, type); return true; }
  catch (error) {
    if (['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return false; }
    throw error;
  }
}

for (const input of inputs) {
  test(`theme export rejects directory symlink alias of ${input}`, t => temporary((root, data, theme) => {
    const alias = join(root, 'linked-data');
    if (!makeSymlink(t, data, alias, 'junction')) return;
    const before = inputs.map(file => readFileSync(join(data, file)));
    let error;
    try { buildUiTheme(theme, data, join(alias, input)); } catch (caught) { error = caught; }
    for (let index = 0; index < inputs.length; index++) assert.equal(readFileSync(join(data, inputs[index])).equals(before[index]), true);
    assert.match(error?.message ?? '', /Output must not overwrite an input file/);
  }));
}

for (const mode of ['symlink', 'hardlink']) {
  test(`theme export allows ${mode} to an existing non-input generated file`, t => temporary((root, data, theme) => {
    const original = join(root, 'original.lua'), alias = join(root, 'alias.lua');
    const expected = buildUiTheme(theme, data, original);
    if (mode === 'symlink' && !makeSymlink(t, original, alias, 'file')) return;
    if (mode === 'hardlink') linkSync(original, alias);
    assert.equal(buildUiTheme(theme, data, alias), expected);
    assert.equal(readFileSync(original, 'utf8'), expected);
    assert.equal(readFileSync(alias, 'utf8'), expected);
  }));
}

for (const input of inputs) {
  test(`theme export rejects symlink-parent traversal output alias of ${input}`, t => temporary((root, data, theme) => {
    const alias = join(root, 'alias');
    mkdirSync(alias);
    if (!makeSymlink(t, join(data, 'presentation'), join(alias, 'presentation'), 'junction')) return;
    // Do not path.join/resolve: the kernel traverses the symlink before '..'.
    const output = `${alias}/presentation/../${input}`;
    const before = inputs.map(file => readFileSync(join(data, file)));
    let error;
    try { buildUiTheme(theme, data, output); } catch (caught) { error = caught; }
    for (let index = 0; index < inputs.length; index++) assert.equal(readFileSync(join(data, inputs[index])).equals(before[index]), true);
    assert.match(error?.message ?? '', /Output must not overwrite an input file/);
  }));
}

test('theme export identifies a theme input read through symlink-parent traversal', t => temporary((root, data, theme) => {
  const alias = join(root, 'alias');
  mkdirSync(alias);
  if (!makeSymlink(t, join(data, 'presentation'), join(alias, 'presentation'), 'junction')) return;
  const rawTheme = `${alias}/presentation/../presentation/ui_theme.json`;
  const before = inputs.map(file => readFileSync(join(data, file)));
  let error;
  try { buildUiTheme(rawTheme, data, theme); } catch (caught) { error = caught; }
  for (let index = 0; index < inputs.length; index++) assert.equal(readFileSync(join(data, inputs[index])).equals(before[index]), true);
  assert.match(error?.message ?? '', /Output must not overwrite an input file/);
}));
