import { readFileSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { prepareReviewedAssets } from './ci-reviewed-lfs.mjs';

export const timings = JSON.parse(readFileSync(new URL('./ci-test-timings.json', import.meta.url), 'utf8'));

export function partition(files, value, weights, fallback, initial) {
  const match = /^([1-9]\d*)\/([1-9]\d*)$/.exec(String(value));
  const [index, count] = match ? match.slice(1).map(Number) : [];
  if (!Number.isSafeInteger(index) || !Number.isSafeInteger(count) || index > count || count > 64) {
    throw new Error('Shard must be i/n with 1 <= i <= n <= 64');
  }
  if (new Set(files).size !== files.length || files.some(file => typeof file !== 'string' || !file)) throw new Error('Files must be unique nonempty paths');
  const weight = file => weights[file] ?? fallback;
  if (files.some(file => !Number.isFinite(weight(file)) || weight(file) <= 0)) throw new Error('Invalid scheduling weight');
  const loads = initial ?? Array(count).fill(0);
  if (loads.length !== count || loads.some(load => !Number.isFinite(load) || load < 0)) throw new Error('Invalid initial loads');
  const bins = loads.map(load => ({ load, files: [] }));
  for (const file of [...files].sort((a, b) => weight(b) - weight(a) || a.localeCompare(b, 'en'))) {
    let target = 0;
    for (let i = 1; i < count; i++) if (bins[i].load < bins[target].load) target = i;
    bins[target].files.push(file);
    bins[target].load += weight(file);
  }
  return { files: bins[index - 1].files.sort(), loads: bins.map(bin => bin.load) };
}

export function jsShard(files, value, platform = process.platform) {
  return partition(files, value, timings.js[platform] ?? {}, timings.unknownJsMs);
}

export function discoverJs(root = '.') {
  const files = readdirSync(resolve(root, 'tests')).filter(file => file.endsWith('.test.mjs')).map(file => `tests/${file}`);
  if (!files.length) throw new Error('No JavaScript test files discovered');
  return files;
}

export function main(args) {
  if (args.length !== 1 || !/^--(shard|prepare)=/.test(args[0])) throw new Error('Usage: ci-shards.mjs --shard=i/n | --prepare=i/n');
  const shard = args[0].split('=')[1], plan = jsShard(discoverJs(), shard);
  console.log(JSON.stringify({ shard, platform: process.platform, ...plan }));
  if (args[0].startsWith('--prepare=')) {
    console.log(JSON.stringify(plan.files.includes('tests/reviewed-traveler-geo-assets.test.mjs')
      ? prepareReviewedAssets() : { status: 'not-needed', shard }));
    return;
  }
  if (!plan.files.length) return;
  // Keep a fresh node:test process for each file, serial execution and native
  // failure/timeout handling. No NODE_TEST_CONTEXT may disable this child CLI.
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;
  const result = spawnSync(process.execPath, ['--test', '--test-concurrency=1', '--test-reporter=spec',
    '--test-reporter=./scripts/ci-timing-reporter.mjs', '--test-reporter-destination=stdout',
    '--test-reporter-destination=build/ci-js-timings.jsonl', ...plan.files], { stdio: 'inherit', env, windowsHide: true });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { main(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
