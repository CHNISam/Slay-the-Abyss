import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const source = join(root, 'experiments/figma-map-native-spike');
const require = createRequire(import.meta.url);

// Discovered by npm test / the existing tests/*.test.mjs CI sharder.
// Build prerequisites are the normal build:data + build:ui; no Host or network.
test('native Figma map slice keeps platform, input and generated-layout regressions', () => {
  const work = mkdtempSync(join(tmpdir(), 'abyss-figma-map-regression-'));
  const run = (args) => {
    const result = spawnSync(process.execPath, args, {
      cwd: work,
      encoding: 'utf8',
      timeout: 30000,
      maxBuffer: 4 * 1024 * 1024,
      env: { ...process.env, ABYSS_ROOT: root, FIGMA_SCENARIO: 'real-wins',
        LUA_INIT: '', LUA_INIT_5_3: '', LUA_PATH: './?.lua;;', LUA_PATH_5_3: './?.lua;;' },
    });
    assert.ifError(result.error);
    assert.equal(result.signal, null, `${args.join(' ')} terminated`);
    assert.equal(result.status, 0, `${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  };
  try {
    // Copy only reproducible source. Never read or trust checked-out generated saves.
    for (const name of readdirSync(source)) {
      if (/\.(?:mjs|lua)$/.test(name) && !/\.generated\.lua$/.test(name)
          && !['controls.lua', 'theme.lua', 'geometry.lua'].includes(name)) {
        cpSync(join(source, name), join(work, name));
      }
    }
    cpSync(join(source, 'tests'), join(work, 'tests'), { recursive: true });
    cpSync(join(source, 'tools'), join(work, 'tools'), { recursive: true });
    run(['build-probe.mjs']);
    run(['build-scene.mjs']);
    const jsTests = readdirSync(join(work, 'tests')).filter(name => name.endsWith('.test.mjs')).sort();
    assert.ok(jsTests.length >= 3, 'layout, probe and pointer regression files required');
    run(['--test', '--test-concurrency=1', ...jsTests.map(name => join('tests', name))]);
    // -e, not positional script: upstream Fengari otherwise loses assertion exit status.
    const cli = require.resolve('fengari-node-cli/src/lua-cli.js');
    run([cli, '-e', 'dofile("tests/curve.lua"); dofile("tests/presentation.lua"); dofile("tests/scene.lua")']);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
