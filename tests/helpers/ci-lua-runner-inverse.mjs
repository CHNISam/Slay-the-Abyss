import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

// Invert only the reviewed scheduling edit. The original whole-runner hash
// still protects every deadline, child process option, output and failure path.
export function originalLuaRunner(source) {
  source=preAcceptedPr323Source('scripts/test-lua.mjs',source);
  source = source.replaceAll('\r\n', '\n');
  const currentUrlImport="import { pathToFileURL, fileURLToPath } from 'node:url';\n";
  assert.equal(source.split(currentUrlImport).length,2,'exact historical root URL import');
  source=source.replace(currentUrlImport,"import { pathToFileURL } from 'node:url';\n");
  for(const addition of [
    "import {runHistoricalPresentation} from '../tests/helpers/historical-presentation-runner.mjs';\n",
    "  if (resolve(cwd) === resolve(fileURLToPath(new URL('..', import.meta.url))) && script.replaceAll('\\\\', '/') === 'tests/lua/presentation_responsibilities_trace.lua') return runHistoricalPresentation(runLua, script, { timeout, cwd, caseName });\n",
  ]){
    assert.equal(source.split(addition).length,2,'one exact original-deadline historical fixture dispatch');
    source=source.replace(addition,'');
  }
  const workerEdits = [
    ["import { runLuaWorkers, luaSchedulingWeight } from './lua-workers.mjs';\n", ''],
    ['    let workers = 1, workersSeen = false;\n', ''],
    [String.raw`      if (args[i] === '--workers') {
        if (workersSeen || !/^[12]$/.test(args[i + 1] ?? '')) throw new Error('Lua workers must be 1 or 2 and specified once');
        workers = Number(args[++i]); workersSeen = true;
      } else if (args[i] === '--shard' && shard === undefined) shard = args[++i] ?? '';`,
      "      if (args[i] === '--shard' && shard === undefined) shard = args[++i] ?? '';"],
    [String.raw`    if (workers === 2 && scripts.length) {
      process.exitCode = await runLuaWorkers(scripts, { cli: process.argv[1], weights: runtimeTimings.lua });
    } else for (const script of scripts) {`, '    for (const script of scripts) {'],
    ['[--shard i/n] [--workers 1|2]', '[--shard i/n]'],
    ['      scripts = shardLuaScripts(scripts, shard, runtimeTimings, workers);', '      scripts = shardLuaScripts(scripts, shard);'],
  ];
  for (const [after, before] of workerEdits) {
    assert.equal(source.split(after).length, 2, 'exact reviewed worker wiring');
    source = source.replace(after, before);
  }
  const dependency = "import { partition, timings as runtimeTimings, jsShard, discoverJs } from './ci-shards.mjs';\n";
  assert.equal(source.split(dependency).length, 2, 'one reviewed scheduler dependency');
  const start = source.indexOf('export function shardLuaScripts(');
  const end = source.indexOf('\n\nif (process.argv[1]', start);
  assert.ok(start >= 0 && end > start, 'complete reviewed scheduling block');
  assert.equal(createHash('sha256').update(source.slice(start, end)).digest('hex'),
    'f2f015e5f7be58876ef34869170e2716a41e7e7e7cb178130bb985f2ef615576',
    'only the exact reviewed scheduler may be inverted');
  const original = String.raw`export function shardLuaScripts(scripts, value) {
  const match = /^([1-9]\d*)\/([1-9]\d*)$/.exec(String(value));
  const index = Number(match?.[1]), count = Number(match?.[2]);
  if (!match || !Number.isSafeInteger(index) || !Number.isSafeInteger(count) || index > count || count > 64) {
    throw new Error('Lua shard must be i/n with integers 1 <= i <= n <= 64');
  }
  return [...scripts].sort().filter((script, position) => position % count === index - 1);
}`;
  return (source.slice(0, start) + original + source.slice(end)).replace(dependency, '');
}
