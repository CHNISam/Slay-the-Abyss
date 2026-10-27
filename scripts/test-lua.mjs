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

export function runLua(script = 'tests/lua/combat.lua', { timeout, cwd = process.cwd(), caseName } = {}) {
  if (caseName !== undefined && (typeof caseName !== 'string' || !caseName.trim())) {
    throw new Error('Selected Lua case must have a nonempty name');
  }
  const cli = require.resolve('fengari-node-cli/src/lua-cli.js');
  // The upstream CLI's positional-script path loses Lua errors' exit status.
  // Its -e path explicitly exits nonzero when dofile raises, including syntax errors.
  const normalizedScript = script.replaceAll('\\', '/');
  const fixture = ['tests/lua/battle_ui.lua', 'tests/lua/battle_ui_slice_2.lua', 'tests/lua/battle_ui_slice_3.lua',
    'tests/lua/battle_ui_slice_4.lua', 'tests/lua/battle_ui_slice_5.lua',
    'tests/lua/battle_ui_slice_6.lua', 'tests/lua/battle_ui_slice_7.lua']
    .some(path => normalizedScript.endsWith(path));
  const mapProperties = ['map_floor_boundaries.lua', 'map_no_crossings.lua', 'map_treasure_placement.lua']
    .some(name => normalizedScript.endsWith(`tests/lua/${name}`));
  // Quality runs 39982640775/39985958741 timed out in three different fixtures
  // (battle UI, game UI, encounter coverage). Allow 30s per independent script,
  // 60s for the full battle/host trees; assertions and explicit caller limits remain.
  // Raw seven-column source maps use limb RNG arithmetic in Fengari. Keep all
  // 128 seeds and strict restores; these three bounded fixtures need more time.
  // The composed host runs the real 17-floor route and seven-column/raw-RNG
  // setup; the unchanged cases exceeded 30s after that production migration.
  const composedHost = normalizedScript.endsWith('tests/lua/game_ui.lua');
  timeout ??= normalizedScript.endsWith('tests/lua/encounter_coverage.lua') ? 120000 : mapProperties ? 120000 : fixture || composedHost ? 60000 : 30000;
  const temporary = fixture ? join(tmpdir(), `abyss-ui-test-${randomUUID()}.lua`) : null;
  if (temporary) writeFileSync(temporary, `ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\ndofile(${luaString(resolve(cwd, script))})\n`);
  let result;
  // Mutation checks target one registered original regression. Each child is
  // fresh; ordinary invocations receive no selector and still run every case.
  const selection = caseName === undefined ? '' : `ABYSS_MUTATION_CASE=${luaString(caseName)};`;
  try { result = spawnSync(process.execPath, [cli, '-e', `${selection}dofile(${luaString(temporary || resolve(cwd, script))})`], {
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

export function shardLuaScripts(scripts, value) {
  const match = /^([1-9]\d*)\/([1-9]\d*)$/.exec(String(value));
  const index = Number(match?.[1]), count = Number(match?.[2]);
  if (!match || !Number.isSafeInteger(index) || !Number.isSafeInteger(count) || index > count || count > 64) {
    throw new Error('Lua shard must be i/n with integers 1 <= i <= n <= 64');
  }
  return [...scripts].sort().filter((script, position) => position % count === index - 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    let script, shard;
    const args = process.argv.slice(2);
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--shard' && shard === undefined) shard = args[++i] ?? '';
      else if (args[i].startsWith('-') || script !== undefined) throw new Error('Usage: test-lua.mjs [script.lua] [--shard i/n]');
      else script = args[i];
    }
    if (shard !== undefined && script !== undefined) throw new Error('Lua sharding cannot be combined with a single script');
    let scripts = script ? [script] : readdirSync('tests/lua')
      .filter(file => file.endsWith('.lua')).sort().map(file => `tests/lua/${file}`);
    if (!scripts.length) throw new Error('No Lua test files discovered');
    if (shard !== undefined) {
      scripts = shardLuaScripts(scripts, shard);
      console.log(`Lua shard ${shard}: ${scripts.length} fixtures`);
    }
    for (const script of scripts) {
      const startedAt = Date.now();
      try {
        const result = runLua(script);
        process.stdout.write(result.stdout);
        process.stderr.write(result.stderr);
        if (result.status !== 0) process.exitCode = result.status ?? 1;
      } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
      } finally {
        console.log(`Lua fixture ${script}: ${Date.now() - startedAt} ms`);
      }
    }
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
