import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUiTheme } from '../scripts/build-ui-theme.mjs';
import { contentFiles } from '../scripts/validate-data.mjs';

function temporary(t, action) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-output-path-'));
  try {
    const data = join(root, 'data');
    cpSync('data', data, { recursive: true });
    action(root, data, (target, link) => {
      try { symlinkSync(target, link, 'junction'); return true; }
      catch (error) {
        if (['EPERM', 'EACCES', 'ENOSYS', 'ENOTSUP'].includes(error.code)) { t.skip(`Symlink unavailable: ${error.code}`); return false; }
        throw error;
      }
    });
  } finally { rmSync(root, { recursive: true, force: true }); }
}
const inputNames = ['presentation/ui_theme.json', ...contentFiles.map(file => `${file}.json`)];
const snapshot = data => inputNames.map(file => readFileSync(join(data, file)));
function unchanged(data, before) {
  inputNames.forEach((file, index) => assert.equal(readFileSync(join(data, file)).equals(before[index]), true, `${file} must remain unchanged`));
}
for (const file of contentFiles) {
  test(`data export rejects symlink-parent traversal into ${file}`, t => temporary(t, (root, data, link) => {
    mkdirSync(join(data, 'inner'));
    if (!link(join(data, 'inner'), join(root, 'alias'))) return;
    const output = `${root}/alias/../${file}.json`;
    const before = snapshot(data);
    let error;
    try { buildLuaData(data, output); } catch (caught) { error = caught; }
    unchanged(data, before);
    assert.match(error?.message ?? '', /Output must not overwrite an input file/);
  }));
}
for (const [name, build] of [
  ['data', (data, output) => buildLuaData(data, output)],
  ['theme', (data, output) => buildUiTheme(join(data, 'presentation/ui_theme.json'), data, output)],
]) {
  test(`${name} export permits safe symlink-parent traversal despite lexical input collision`, t => temporary(t, (root, data, link) => {
    const out = join(root, 'out');
    mkdirSync(join(out, 'inner'), { recursive: true });
    if (!link(join(out, 'inner'), join(data, 'link'))) return;
    const output = `${data}/link/../cards.json`;
    const before = snapshot(data);
    const expected = build(data, join(root, 'baseline.lua'));
    assert.equal(build(data, output), expected);
    assert.equal(readFileSync(join(out, 'cards.json'), 'utf8'), expected);
    assert.equal(build(data, output), expected);
    unchanged(data, before);
  }));
}
