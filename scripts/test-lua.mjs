import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { luaString } from './build-lua-data.mjs';

const require = createRequire(import.meta.url);

export function runLua(script = 'tests/lua/combat.lua', { timeout = 15000, cwd = process.cwd() } = {}) {
  const cli = require.resolve('fengari-node-cli/src/lua-cli.js');
  // The upstream CLI's positional-script path loses Lua errors' exit status.
  // Its -e path explicitly exits nonzero when dofile raises, including syntax errors.
  const result = spawnSync(process.execPath, [cli, '-e', `dofile(${luaString(resolve(cwd, script))})`], {
    cwd, encoding: 'utf8', timeout, maxBuffer: 1024 * 1024,
    env: { ...process.env, LUA_PATH: './build/lua/?.lua;./src/lua/?.lua;;', LUA_PATH_5_3: './build/lua/?.lua;./src/lua/?.lua;;', LUA_INIT: '', LUA_INIT_5_3: '' }
  });
  if (result.error) throw new Error(`Lua runner failed: ${result.error.message}`, { cause: result.error });
  if (result.signal) throw new Error(`Lua runner terminated by ${result.signal}`);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = runLua(process.argv[2]);
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    process.exitCode = result.status ?? 1;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
