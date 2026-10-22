import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, symlinkSync, linkSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, relative } from 'node:path';
import { spawnSync } from 'node:child_process';
import { contentFiles } from '../scripts/validate-data.mjs';

const script = resolve('scripts/build-lua-data.mjs');
for (const kind of ['direct', 'relative', 'symlink', 'hardlink']) {
  for (const file of contentFiles) {
    test(`reject ${kind} output alias of ${file}; preserve all six inputs`, t => {
      const root = mkdtempSync(join(tmpdir(), 'abyss-output-'));
      try {
        const data = join(root, 'data');
        mkdirSync(data);
        for (const name of contentFiles) copyFileSync(resolve('data', `${name}.json`), join(data, `${name}.json`));
        const before = contentFiles.map(name => readFileSync(join(data, `${name}.json`)));
        const target = join(data, `${file}.json`);
        let output = target;
        if (kind === 'relative') output = relative(process.cwd(), target);
        if (kind === 'symlink' || kind === 'hardlink') {
          output = join(root, 'output.lua');
          if (kind === 'symlink') {
            try { symlinkSync(target, output); }
            catch (error) {
              if (['EPERM', 'ENOTSUP'].includes(error.code)) {
                t.skip(`Environment cannot create symlinks: ${error.code}; alias protection not exercised`);
                return;
              }
              throw error;
            }
          }
          else linkSync(target, output);
        }
        const result = spawnSync(process.execPath, [script, data, output], { encoding: 'utf8', timeout: 10000 });
        assert.equal(result.status, 1, result.stdout + result.stderr);
        assert.match(result.stderr, /output.*input/i);
        contentFiles.forEach((name, i) => assert.deepEqual(readFileSync(join(data, `${name}.json`)), before[i], name));
      } finally { rmSync(root, { recursive: true, force: true }); }
    });
  }
}

test('new output and ordinary overwrite remain supported', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-output-ok-'));
  const output = join(root, 'nested', 'output.lua');
  const before = contentFiles.map(name => readFileSync(resolve('data', `${name}.json`)));
  try {
    for (const existing of [false, true]) {
      if (existing) writeFileSync(output, 'old generated output');
      const result = spawnSync(process.execPath, [script, 'data', output], { encoding: 'utf8', timeout: 10000 });
      assert.equal(result.status, 0, result.stderr);
      assert.match(readFileSync(output, 'utf8'), /^-- Generated from validated JSON\./);
      contentFiles.forEach((name, i) => assert.deepEqual(readFileSync(resolve('data', `${name}.json`)), before[i], name));
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});
