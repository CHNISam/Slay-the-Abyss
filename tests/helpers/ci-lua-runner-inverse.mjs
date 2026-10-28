import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

// Invert only the reviewed scheduling edit. The original whole-runner hash
// still protects every deadline, child process option, output and failure path.
export function originalLuaRunner(source) {
  source = source.replaceAll('\r\n', '\n');
  const dependency = "import { partition, timings as runtimeTimings, jsShard, discoverJs } from './ci-shards.mjs';\n";
  assert.equal(source.split(dependency).length, 2, 'one reviewed scheduler dependency');
  const start = source.indexOf('export function shardLuaScripts(');
  const end = source.indexOf('\n\nif (process.argv[1]', start);
  assert.ok(start >= 0 && end > start, 'complete reviewed scheduling block');
  assert.equal(createHash('sha256').update(source.slice(start, end)).digest('hex'),
    '64f2b495c06d0111ba307084136c8e034232fa79965cd1f9a6cccd8ee47cb0a6',
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
