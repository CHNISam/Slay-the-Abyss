// Local evidence only: no fetch, LFS pull, pruning, history rewrite or official package claim.
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, readlinkSync, realpathSync, writeFileSync } from 'node:fs';
import { join, resolve, relative, parse, sep } from 'node:path';
import { platform, release } from 'node:os';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';

const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const lfsPrefix = 'version https://git-lfs.github.com/spec/v1';
export const requiredBuildOutputs = ['abyss_data.lua', 'abyss_theme.lua', 'battle-ui.json', 'game-ui.json',
  'abyss_ui_layout.lua', 'abyss_ui_templates.lua', 'abyss_presentation.lua'];
function firstSymlink(path) {
  const absolute = resolve(path), base = parse(absolute).root;
  let current = base;
  for (const part of relative(base, absolute).split(sep)) {
    current = join(current, part);
    try { if (lstatSync(current).isSymbolicLink()) return current; }
    catch (error) { if (error.code === 'ENOENT') return null; throw error; }
  }
  return null;
}
function assertSafeOutput(path) {
  if (firstSymlink(path)) throw new Error('Output path must not contain a symlink');
}
function git(root, args, input, encoding = 'utf8') {
  const result = spawnSync('git', args, { cwd: root, input, encoding,
    env: { ...process.env, GIT_NO_LAZY_FETCH: '1', GIT_TERMINAL_PROMPT: '0' },
    windowsHide: true, timeout: 30000, maxBuffer: 32 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`Git ${args[0]} failed: ${result.error?.message ?? result.stderr}`);
  return result.stdout;
}
function sourceIdentity(root) {
  return { commit: git(root, ['rev-parse', 'HEAD']).trim(), tree: git(root, ['rev-parse', 'HEAD^{tree}']).trim(),
    trackedChanges: git(root, ['diff', '--name-only', 'HEAD', '--']).trim().length > 0 };
}
function treeEntries(root) {
  return git(root, ['ls-tree', '-rlz', '--full-tree', 'HEAD']).split('\0').filter(Boolean).map(line => {
    const match = /^(\d{6}) (blob|commit) ([0-9a-f]+) +(-|\d+)\t([\s\S]+)$/.exec(line);
    if (!match) throw new Error('Invalid Git tree entry');
    return { mode: match[1], type: match[2], oid: match[3], bytes: match[4] === '-' ? null : Number(match[4]), path: match[5] };
  });
}
function smallBlobs(root, entries) {
  const objects = [...new Map(entries.filter(x => x.type === 'blob' && x.bytes <= 1024).map(x => [x.oid, x])).values()];
  if (!objects.length) return new Map();
  const output = git(root, ['cat-file', '--batch'], objects.map(x => x.oid).join('\n') + '\n', null);
  const blobs = new Map(); let offset = 0;
  for (const entry of objects) {
    const end = output.indexOf(10, offset), header = output.subarray(offset, end).toString();
    if (header !== `${entry.oid} blob ${entry.bytes}`) throw new Error('Invalid Git batch object header');
    offset = end + 1;
    if (output[offset + entry.bytes] !== 10) throw new Error('Invalid Git batch object body');
    blobs.set(entry.oid, output.subarray(offset, offset + entry.bytes)); offset += entry.bytes + 1;
  }
  if (offset !== output.length) throw new Error('Unexpected Git batch output');
  return blobs;
}
function pointer(bytes, path) {
  const text = bytes?.toString('utf8') ?? '';
  if (!text.startsWith(lfsPrefix)) return null;
  const match = /^version https:\/\/git-lfs.github.com\/spec\/v1\noid sha256:([0-9a-f]{64})\nsize (0|[1-9]\d*)\n$/.exec(text);
  if (!match || !Number.isSafeInteger(Number(match[2]))) throw new Error(`Invalid LFS pointer: ${path}`);
  return { oid: match[1], bytes: Number(match[2]) };
}
function fileState(path, object) {
  if (firstSymlink(path)) return 'symlink';
  let stat;
  try { stat = lstatSync(path); } catch (error) { if (error.code === 'ENOENT') return 'missing'; throw error; }
  if (!stat.isFile()) return 'not-file';
  if (stat.size !== object.bytes && stat.size > 1024) return 'corrupt';
  const bytes = readFileSync(path);
  if (stat.size === object.bytes && sha256(bytes) === object.oid) return 'verified';
  if (stat.size <= 1024) {
    try {
      const candidate = pointer(bytes, path);
      if (candidate?.oid === object.oid && candidate.bytes === object.bytes) return 'pointer';
    }
    catch (error) { if (!error.message.startsWith('Invalid LFS pointer:')) throw error; }
  }
  return 'corrupt';
}

function lfsObjectDirectory(root) {
  // LFS shares storage across linked worktrees, unlike rev-parse --git-path lfs/objects.
  // lfs.storage is a literal path (no tilde expansion), relative to the common Git dir.
  const common = git(root, ['rev-parse', '--path-format=absolute', '--git-common-dir']).replace(/\r?\n$/, '');
  const storage = git(root, ['config', '--default', 'lfs', '--get', 'lfs.storage']).replace(/\r?\n$/, '') || 'lfs';
  return resolve(common, storage, 'objects');
}

export function inspectRepository(root = process.cwd()) {
  root = realpathSync(git(realpathSync(root), ['rev-parse', '--show-toplevel']).replace(/\r?\n$/, ''));
  const entries = treeEntries(root), blobs = entries.filter(x => x.type === 'blob'), small = smallBlobs(root, entries);
  const groups = new Map(), objects = new Map(), paths = [];
  let cacheDirectory;
  for (const entry of blobs) {
    if (!groups.has(entry.oid)) groups.set(entry.oid, { oid: entry.oid, bytes: entry.bytes, paths: [] });
    groups.get(entry.oid).paths.push(entry.path);
    const object = entry.mode === '120000' ? null : pointer(small.get(entry.oid), entry.path);
    if (!object) continue;
    if (objects.has(object.oid) && objects.get(object.oid).bytes !== object.bytes) throw new Error(`Conflicting LFS sizes: ${object.oid}`);
    if (!objects.has(object.oid)) {
      cacheDirectory ??= lfsObjectDirectory(root);
      const cachePath = join(cacheDirectory, object.oid.slice(0, 2), object.oid.slice(2, 4), object.oid);
      objects.set(object.oid, { ...object, cache: fileState(cachePath, object), paths: [] });
    }
    const record = { path: entry.path, ...object, pointerBytes: entry.bytes, worktree: fileState(join(root, entry.path), object) };
    paths.push(record); objects.get(object.oid).paths.push(entry.path);
  }
  const unique = [...groups.values()], lfsObjects = [...objects.values()];
  const sum = (items, key) => items.reduce((total, item) => total + item[key], 0);
  const checkoutBlobBytes = sum(blobs, 'bytes'), pointerBytes = sum(paths, 'pointerBytes');
  const countObjects = Object.fromEntries(git(root, ['count-objects', '-v']).trim().split('\n').map(line => {
    const [key, value] = line.split(': '); return [key, Number(value)];
  }));
  return { schemaVersion: 1, source: sourceIdentity(root),
    git: { blobPaths: blobs.length, uniqueBlobs: unique.length, checkoutBlobBytes, uniqueBlobBytes: sum(unique, 'bytes'),
      submodules: entries.filter(x => x.type === 'commit').map(x => x.path),
      localObjectStore: { ...countObjects, sizeUnit: 'KiB for size, size-pack and size-garbage; local history, not network transfer' },
      largestBlobs: [...unique].sort((a, b) => b.bytes - a.bytes).slice(0, 20),
      repeatedBlobs: unique.filter(x => x.paths.length > 1).sort((a, b) => b.bytes * (b.paths.length - 1) - a.bytes * (a.paths.length - 1)) },
    lfs: { pointerPaths: paths.length, uniqueObjects: lfsObjects.length, pointerBytes,
      uniquePayloadBytes: sum(lfsObjects, 'bytes'), logicalCheckoutPayloadBytes: sum(paths, 'bytes'),
      verifiedWorktreeBytes: sum(paths.filter(x => x.worktree === 'verified'), 'bytes'),
      readableUniqueBytes: sum(lfsObjects.filter(x => x.cache === 'verified' || paths.some(p => p.oid === x.oid && p.worktree === 'verified')), 'bytes'),
      paths, objects: lfsObjects },
    checkout: { logicalBytesWithAllLfs: checkoutBlobBytes - pointerBytes + sum(paths, 'bytes'),
      measuredNetworkTransferBytes: null, note: 'Logical file bytes only. No network transfer was performed or inferred.' },
    officialCandidateBytes: null };
}

function inputDigest(root) {
  const digest = createHash('sha256');
  const files = git(root, ['ls-files', '-z', '--cached', '--others', '--exclude-standard']).split('\0').filter(Boolean).sort();
  for (const path of files) {
    digest.update(path + '\0');
    const absolute = join(root, path);
    const linked = firstSymlink(absolute);
    if (linked) { digest.update(`link:${relative(root, linked)}:${readlinkSync(linked)}\0`); continue; }
    if (!existsSync(absolute)) { digest.update('missing\0'); continue; }
    const stat = lstatSync(absolute);
    digest.update(stat.isFile() ? readFileSync(absolute) : 'not-file');
    digest.update('\0');
  }
  return digest.digest('hex');
}
function outputReceipt(directory) {
  const result = [];
  function visit(path) {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const file = join(path, entry.name);
      if (entry.isDirectory()) visit(file);
      else if (entry.isFile()) { const bytes = readFileSync(file); result.push({ path: relative(directory, file).replaceAll('\\', '/'), bytes: bytes.length, sha256: sha256(bytes) }); }
      else throw new Error('Generated output is not a regular file or directory');
    }
  }
  visit(directory); return result.sort((a, b) => a.path.localeCompare(b.path, 'en'));
}
function buildPass(root, output) {
  const commands = [
    ['scripts/build-lua-data.mjs', 'data', join(output, 'abyss_data.lua')],
    ['scripts/build-ui.mjs', output],
    ['scripts/build-ui-theme.mjs', 'data/presentation/ui_theme.json', 'data', join(output, 'abyss_theme.lua')],
  ];
  const started = performance.now(), steps = [];
  for (const args of commands) {
    const start = performance.now();
    const child = spawnSync(process.execPath, args, { cwd: root, encoding: 'utf8', timeout: 120000, windowsHide: true, maxBuffer: 1024 * 1024 });
    steps.push({ command: ['node', ...args.map(arg => arg.replace(output, '<output>'))], wallMs: performance.now() - start,
      exitCode: child.status, signal: child.signal, error: child.error?.message ?? null, stdout: child.stdout, stderr: child.stderr });
    if (child.error || child.status !== 0) return { status: 'failed', wallMs: performance.now() - started, steps, outputs: null };
  }
  const outputs = outputReceipt(output);
  const missingOutputs = requiredBuildOutputs.filter(path => !outputs.some(file => file.path === path && file.bytes > 0));
  return { status: missingOutputs.length ? 'failed' : 'passed', wallMs: performance.now() - started, steps, outputs, missingOutputs };
}
function quantiles(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return { count: sorted.length, p50Ms: sorted[Math.ceil(sorted.length * 0.5) - 1], p95Ms: sorted[Math.ceil(sorted.length * 0.95) - 1], method: 'nearest rank; descriptive small sample, not a service-level guarantee' };
}
export function measureBuilds(root = process.cwd(), { rounds = 3 } = {}) {
  if (!Number.isInteger(rounds) || rounds < 1 || rounds > 10) throw new Error('rounds must be an integer from 1 to 10');
  root = realpathSync(root);
  assertSafeOutput(join(root, 'build'));
  const source = { ...sourceIdentity(root), inputDigest: inputDigest(root) };
  mkdirSync(join(root, 'build'), { recursive: true });
  const runDirectory = mkdtempSync(join(root, 'build', 'repository-costs-'));
  const pairs = []; let status = 'passed';
  for (let round = 0; round < rounds; round++) {
    const output = join(runDirectory, `pair-${round + 1}`);
    mkdirSync(output);
    const cold = buildPass(root, output), warm = cold.status === 'passed' ? buildPass(root, output) : null;
    const identicalOutputs = !!warm && warm.status === 'passed' && JSON.stringify(cold.outputs) === JSON.stringify(warm.outputs);
    const baseline = pairs[0]?.cold.outputs ?? cold.outputs;
    const matchesBaseline = identicalOutputs && JSON.stringify(cold.outputs) === JSON.stringify(baseline);
    pairs.push({ round: round + 1, cold, warm, identicalOutputs, matchesBaseline });
    if (!matchesBaseline) { status = 'failed'; break; }
  }
  const finalInputDigest = inputDigest(root);
  if (source.inputDigest !== finalInputDigest) status = 'failed';
  return { status, source, finalInputDigest,
    inputDigestScope: 'Tracked and nonignored untracked paths and bytes, without following symlinks. Ignored dependencies and external link targets are not authenticated.',
    environment: { node: process.version, platform: platform(), osRelease: release(), python: spawnSync(process.env.ABYSS_PYTHON || 'python', ['--version'], { encoding: 'utf8', timeout: 10000 }).stdout?.trim() ?? null },
    coldDefinition: 'Fresh generated output directory and fresh child processes; OS page cache and dependency cache are not cleared.',
    warmDefinition: 'Same output directory, same commands, fresh child processes; no claimed application cache hit.',
    scope: 'Default offline data/UI/theme build only; art-enabled production candidate, network transfer and official import are not measured.',
    runDirectory: relative(root, runDirectory).replaceAll('\\', '/'), pairs,
    summary: status === 'passed' ? { cold: quantiles(pairs.map(x => x.cold.wallMs)), warm: quantiles(pairs.map(x => x.warm.wallMs)) } : null };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2);
    if (args.some(arg => arg !== '--builds' && !/^--rounds=[1-9]\d*$/.test(arg))) throw new Error('Usage: node scripts/repository-costs.mjs [--builds] [--rounds=3]');
    assertSafeOutput(join(realpathSync(process.cwd()), 'build', 'repository-costs.json'));
    const report = { ...inspectRepository(), builds: args.includes('--builds') ? measureBuilds(undefined, { rounds: Number(args.find(x => x.startsWith('--rounds='))?.slice(9) ?? 3) }) : null };
    mkdirSync('build', { recursive: true });
    writeFileSync('build/repository-costs.json', JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({ report: 'build/repository-costs.json', commit: report.source.commit, blobPaths: report.git.blobPaths, lfsObjects: report.lfs.uniqueObjects, builds: report.builds?.status ?? 'not-run' }));
    if (report.builds?.status === 'failed') process.exitCode = 1;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
