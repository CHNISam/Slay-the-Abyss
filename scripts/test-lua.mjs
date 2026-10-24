import { spawnSync } from 'node:child_process';
import { readdirSync, writeFileSync, unlinkSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { createRequire } from 'node:module';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { luaString, toLua } from './build-lua-data.mjs';
import { battleLayout } from './ui-layout.mjs';

const require = createRequire(import.meta.url);

export function runLua(script = 'tests/lua/combat.lua', { timeout, cwd = process.cwd() } = {}) {
  const cli = require.resolve('fengari-node-cli/src/lua-cli.js');
  // The upstream CLI's positional-script path loses Lua errors' exit status.
  // Its -e path explicitly exits nonzero when dofile raises, including syntax errors.
  const normalizedScript = script.replaceAll('\\', '/');
  const fixture = normalizedScript.endsWith('tests/lua/battle_ui.lua');
  const mapProperties = ['map_floor_boundaries.lua', 'map_no_crossings.lua', 'map_treasure_placement.lua']
    .some(name => normalizedScript.endsWith(`tests/lua/${name}`));
  // Quality runs 39982640775/39985958741 timed out in three different fixtures
  // (battle UI, game UI, encounter coverage). Allow 30s per independent script,
  // 60s for the full battle tree; assertions and explicit caller limits remain.
  // Raw seven-column source maps use limb RNG arithmetic in Fengari. Keep all
  // 128 seeds and strict restores; these three bounded fixtures need more time.
  timeout ??= normalizedScript.endsWith('tests/lua/encounter_coverage.lua') ? 120000 : mapProperties ? 120000 : fixture ? 60000 : 30000;
  const temporary = fixture ? join(tmpdir(), `abyss-ui-test-${randomUUID()}.lua`) : null;
  if (temporary) writeFileSync(temporary, `ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\ndofile(${luaString(resolve(cwd, script))})\n`);
  let result;
  try { result = spawnSync(process.execPath, [cli, '-e', `dofile(${luaString(temporary || resolve(cwd, script))})`], {
    cwd, encoding: 'utf8', timeout, maxBuffer: 1024 * 1024,
    env: { ...process.env, LUA_PATH: './build/lua/?.lua;./src/lua/?.lua;;', LUA_PATH_5_3: './build/lua/?.lua;./src/lua/?.lua;;', LUA_INIT: '', LUA_INIT_5_3: '' }
  }); } finally { if (temporary) unlinkSync(temporary); }
  if (result.error) {
    // Keep the last completed groups visible on timeout in both CLI and node:test.
    // The child is still a failure, with its original error retained as the cause.
    const output = [
      result.stdout ? `\n--- Lua stdout ---\n${result.stdout}` : '',
      result.stderr ? `\n--- Lua stderr ---\n${result.stderr}` : '',
    ].join('');
    throw new Error(`Lua runner failed (${script}, ${timeout} ms): ${result.error.message}${output}`, { cause: result.error });
  }
  if (result.signal) throw new Error(`Lua runner terminated by ${result.signal}`);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const scripts = process.argv[2] ? [process.argv[2]] : readdirSync('tests/lua')
      .filter(file => file.endsWith('.lua')).sort().map(file => `tests/lua/${file}`);
    if (!scripts.length) throw new Error('No Lua test files discovered');
    for (const script of scripts) {
      const startedAt = Date.now();
      const result = runLua(script);
      process.stdout.write(result.stdout);
      process.stderr.write(result.stderr);
      console.log(`Lua fixture ${script}: ${Date.now() - startedAt} ms`);
      if (result.status !== 0) { process.exitCode = result.status ?? 1; break; }
    }
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
