// Read-only CI materialization for the four reviewed PNGs, not a general asset downloader.
import { createHash } from 'node:crypto';
import { globSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

export const reviewedPngPaths = ['armaments', 'heavy_blade'].flatMap(id =>
  ['source.png', 'preview-native.png'].map(name => `art/cards/traveler-geo/${id}/${name}`));
export const maxReviewedPngBytes = 3580349;
export const frozenObjects = [
  ['e63cd8703ce983eb1556efa31a017b803e31c7b887e9c3e14c77bd3ba9928332', 1750604],
  ['b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff', 30121],
  ['f396062d29b6845b58bf0043c1941a2219d9ca501ae6520c8579d555d73008d5', 1769446],
  ['6fefbbcbdaa503a1df1c04d282dc9f8cac0fdb36fb189e75aa89427b438b30b1', 30178],
];
const assetTest = 'tests/reviewed-traveler-geo-assets.test.mjs';
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export function needsReviewedAssets(files, shard) {
  if (shard === undefined) return true; // The standalone license audit reads every inventory entry.
  const match = /^([1-9]\d*)\/([1-9]\d*)$/.exec(shard);
  const [index, total] = match ? match.slice(1).map(Number) : [];
  if (!Number.isSafeInteger(index) || !Number.isSafeInteger(total) || index > total) throw new Error('Invalid shard');
  // Node 24 sorts glob results then selects index % total. Native-CLI tests
  // exercise this before/after new test names are inserted; never freeze a shard number.
  const position = files.map(file => file.replaceAll('\\', '/')).sort().indexOf(assetTest);
  if (position < 0) throw new Error('The reviewed asset test is missing from the shard input');
  return position % total === index - 1;
}

export function verifyReviewedPngs(root) {
  let bytesTotal = 0;
  for (const [index, path] of reviewedPngPaths.entries()) {
    const parts = path.split('/');
    const record = JSON.parse(readFileSync(resolve(root, ...parts.slice(0,-1), 'asset.json'), 'utf8')).files[parts.at(-1)];
    if (!record || record.sha256 !== frozenObjects[index][0] || record.bytes !== frozenObjects[index][1]) throw new Error(`Invalid frozen reviewed PNG metadata: ${path}`);
    let bytes;
    try { bytes = readFileSync(resolve(root, path)); } catch (error) { if (error.code !== 'ENOENT') throw error; bytes = Buffer.alloc(0); }
    if (bytes.length !== record.bytes || !bytes.subarray(0,8).equals(pngSignature) || createHash('sha256').update(bytes).digest('hex') !== record.sha256) {
      const error = new Error(`File is not the reviewed PNG: ${path}`); error.code = 'ERR_REVIEWED_PNG'; throw error;
    }
    bytesTotal += bytes.length;
  }
  return { count: reviewedPngPaths.length, bytes: bytesTotal };
}

function verifyPointerBudget(root, env) {
  const objects = reviewedPngPaths.map(path => {
    const shown = spawnSync('git', ['show', ':' + path], { cwd: root,
      env: lfsEnvironment({ ...env, CI_LFS_TOKEN: '' }), encoding: 'utf8',
      windowsHide: true, timeout: 10000, maxBuffer: 1024 });
    const match = /^version https:\/\/git-lfs.github.com\/spec\/v1\noid sha256:([0-9a-f]{64})\nsize ([1-9]\d*)\n$/.exec(shown.stdout ?? '');
    if (shown.error || shown.status !== 0 || !match || !Number.isSafeInteger(Number(match[2]))) throw new Error(`Invalid reviewed LFS index pointer: ${path}`);
    return [match[1], Number(match[2])];
  });
  const total = objects.reduce((sum, object) => sum + object[1], 0);
  if (total > maxReviewedPngBytes) throw new Error(`Reviewed LFS payload exceeds ${maxReviewedPngBytes} bytes; no transfer allowed`);
  for (const [index, [oid, size]] of objects.entries()) {
    if (oid !== frozenObjects[index][0] || size !== frozenObjects[index][1]) throw new Error(`LFS pointer does not match the frozen reviewed object: ${reviewedPngPaths[index]}`);
  }
}

export const lfsArguments = ['-c', 'credential.helper=', '-c', 'lfs.transfer.maxretries=0',
  '-c', 'lfs.dialtimeout=15', '-c', 'lfs.tlstimeout=15', '-c', 'lfs.activitytimeout=30',
  '-c', 'filter.lfs.clean=git-lfs clean -- %f', '-c', 'filter.lfs.smudge=git-lfs smudge -- %f',
  '-c', 'filter.lfs.process=git-lfs filter-process', '-c', 'filter.lfs.required=true',
  'lfs', 'pull', '--include', reviewedPngPaths.join(','), '--exclude', ''];

export function lfsEnvironment(env = process.env) {
  const childEnv = { ...env, GIT_TERMINAL_PROMPT: '0', GIT_LFS_SKIP_SMUDGE: '1', GIT_NO_LAZY_FETCH: '1' };
  delete childEnv.CI_LFS_TOKEN;
  if (env.CI_LFS_TOKEN) {
    // Process-only Git config: no credential persistence or new scopes. Never log this environment.
    childEnv.GIT_CONFIG_COUNT = '1';
    childEnv.GIT_CONFIG_KEY_0 = 'http.https://github.com/.extraheader';
    childEnv.GIT_CONFIG_VALUE_0 = 'AUTHORIZATION: basic ' + Buffer.from(`x-access-token:${env.CI_LFS_TOKEN}`).toString('base64');
  }
  return childEnv;
}

export function prepareReviewedAssets({ root = process.cwd(), shard, env = process.env } = {}) {
  const files = shard === undefined ? [] : globSync('tests/*.test.mjs', { cwd: root });
  if (!needsReviewedAssets(files, shard)) return { status: 'not-needed', shard };
  verifyPointerBudget(root, env); // Also reject stale/mismatched index pointers on a cache hit.
  try { return { status: 'cached', ...verifyReviewedPngs(root) }; }
  catch (error) { if (error.code !== 'ERR_REVIEWED_PNG') throw error; }
  const pulled = spawnSync('git', lfsArguments, { cwd: root, env: lfsEnvironment(env), encoding: 'utf8', windowsHide: true, timeout: 90000, maxBuffer: 1024 * 1024 });
  // Git/LFS stderr can contain remote URLs or headers: do not echo it with a read token in scope.
  if (pulled.error || pulled.status !== 0) throw new Error(`Reviewed PNG LFS materialization failed (exit ${pulled.status ?? 'timeout/start-error'}); no verified PNG result`);
  const verified = verifyReviewedPngs(root); // Required after pull, even when Git exits zero.
  return { status: 'materialized', ...verified };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2);
    if (args.length > 1 || (args.length && !args[0].startsWith('--shard='))) throw new Error('Usage: node scripts/ci-reviewed-lfs.mjs [--shard=i/n]');
    console.log(JSON.stringify(prepareReviewedAssets({ shard: args[0]?.slice('--shard='.length) })));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
