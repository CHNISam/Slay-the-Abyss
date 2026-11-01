// Read-only CI materialization for the six current reviewed PNGs, not a general asset downloader.
import { createHash } from 'node:crypto';
import { globSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

export const reviewedPngPaths = ['armaments', 'cleave', 'heavy_blade'].flatMap(id =>
  ['source.png', 'preview-native.png'].map(name => `art/cards/traveler-geo/${id}/${name}`));
export const maxReviewedPngBytes = 5983528;
export const frozenObjects = [
  ['e63cd8703ce983eb1556efa31a017b803e31c7b887e9c3e14c77bd3ba9928332', 1750604],
  ['b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff', 30121],
  ['6e37a7b9264154a2cd7e6560a625cf001b3b00d63e8fdbf4d01369a714397155', 2091086],
  ['271c49cc6248cf46ea029cc63387c682858b43c29288eb32b44d24175e662b39', 36567],
  ['1cf7dec3ef1f9ae369837204c24b0ce727142909f200c225d252dd85760bdbfc', 2041123],
  ['aefb4d2ca114a8738029249fba8b1bdc4f6235be648684cbfe348ed496388936', 34027],
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

// Independent runtime build inputs: previews only, never the reviewed source PNGs.
// These identities are pinned to the build input contracts, not a directory glob.
export const runtimePreviewPaths = [
  "art/cards/traveler-geo/armaments/preview-native.png",
  "art/cards/traveler-geo/cleave/preview-native.png",
  "art/cards/traveler-geo/heavy_blade/preview-native.png",
  "art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png"
];
export const runtimePreviewObjects = [
  ["b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff", 30121],
  ["271c49cc6248cf46ea029cc63387c682858b43c29288eb32b44d24175e662b39", 36567],
  ["aefb4d2ca114a8738029249fba8b1bdc4f6235be648684cbfe348ed496388936", 34027],
  ["e23d1daac5e7046f9119edbd6179fd16fa31abd245c24d395adfd1af31a91a43", 81155],
];
export const maxRuntimePreviewBytes = 181870;
export const runtimePreviewArguments = [...lfsArguments.slice(0, -6),
  'lfs', 'pull', '--include', runtimePreviewPaths.join(','), '--exclude', ''];

function verifyRuntimePreview(root, index) {
    const path = runtimePreviewPaths[index];
    const [oid, size] = runtimePreviewObjects[index];
    let bytes;
    try { bytes = readFileSync(resolve(root, path)); }
    catch (error) { if (error.code !== 'ENOENT') throw error; bytes = Buffer.alloc(0); }
    if (bytes.length !== size || !bytes.subarray(0, 8).equals(pngSignature)
      || createHash('sha256').update(bytes).digest('hex') !== oid) {
      const error = new Error(`File is not the frozen runtime preview PNG: ${path}`);
      error.code = 'ERR_RUNTIME_PREVIEW_PNG'; throw error;
    }
    return bytes.length;
}

export function verifyRuntimePreviews(root) {
  const bytes = runtimePreviewPaths.reduce((total, _, index) => total + verifyRuntimePreview(root, index), 0);
  return { count: runtimePreviewPaths.length, bytes };
}

// JS consumers may launch art-enabled builds through helpers or subprocesses.
// Conservatively cover any selected JS file; empty/Lua-only/default-off builds
// do not need these inputs. No directory scanning expands the four-object group.
export function needsRuntimePreviews(files) {
  return files.some(file => /^tests\/[^/]+\.test\.mjs$/.test(file));
}

export function prepareRuntimePreviews({ root = process.cwd(), needed = false, env = process.env } = {}) {
  if (needed !== true && needed !== false) throw new Error('Runtime preview selection must be boolean');
  if (!needed) return { status: 'not-needed' };
  let total = 0;
  for (const [index, path] of runtimePreviewPaths.entries()) {
    const shown = spawnSync('git', ['show', ':' + path], { cwd: root,
      env: lfsEnvironment({ ...env, CI_LFS_TOKEN: '' }), encoding: 'utf8',
      windowsHide: true, timeout: 10000, maxBuffer: 1024 });
    const match = /^version https:\/\/git-lfs.github.com\/spec\/v1\noid sha256:([0-9a-f]{64})\nsize ([1-9]\d*)\n$/.exec(shown.stdout ?? '');
    if (shown.error || shown.status !== 0 || !match || !Number.isSafeInteger(Number(match[2])))
      throw new Error(`Invalid runtime preview LFS index pointer: ${path}`);
    const [oid, size] = runtimePreviewObjects[index];
    if (match[1] !== oid || Number(match[2]) !== size)
      throw new Error(`LFS pointer does not match the frozen runtime preview object: ${path}`);
    total += size;
  }
  if (total > maxRuntimePreviewBytes) throw new Error(`Runtime preview payload exceeds ${maxRuntimePreviewBytes} bytes; no transfer allowed`);
  try { return { status: 'cached', ...verifyRuntimePreviews(root) }; }
  catch (error) { if (error.code !== 'ERR_RUNTIME_PREVIEW_PNG') throw error; }
  // Pull only missing/corrupt members of the frozen group. Shared reviewed
  // previews already verified above need no transfer even if their cache is gone.
  const missing = runtimePreviewPaths.filter((_, index) => {
    try { verifyRuntimePreview(root, index); return false; }
    catch (error) { if (error.code !== 'ERR_RUNTIME_PREVIEW_PNG') throw error; return true; }
  });
  if (!missing.length) return { status: 'cached', ...verifyRuntimePreviews(root) };
  const args = [...runtimePreviewArguments];
  args[args.indexOf('--include') + 1] = missing.join(',');
  const pulled = spawnSync('git', args, { cwd: root, env: lfsEnvironment(env), encoding: 'utf8', windowsHide: true, timeout: 90000, maxBuffer: 1024 * 1024 });
  if (pulled.error || pulled.status !== 0) throw new Error(`Runtime preview LFS materialization failed (exit ${pulled.status ?? 'timeout/start-error'}); no verified PNG result`);
  return { status: 'materialized', ...verifyRuntimePreviews(root) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2);
    if (args.length > 1 || (args.length && !args[0].startsWith('--shard='))) throw new Error('Usage: node scripts/ci-reviewed-lfs.mjs [--shard=i/n]');
    console.log(JSON.stringify(prepareReviewedAssets({ shard: args[0]?.slice('--shard='.length) })));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
