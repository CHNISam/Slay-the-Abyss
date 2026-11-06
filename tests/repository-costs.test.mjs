import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { inspectRepository, measureBuilds, requiredBuildOutputs } from '../scripts/repository-costs.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-repo-cost-test-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  git('init', '-q'); git('config', 'core.autocrlf', 'false');
  git('config', 'user.email', 'cost-test@example.invalid'); git('config', 'user.name', 'Cost test');
  const payload = Buffer.from('verified asset bytes');
  const oid = hash(payload);
  const pointer = `version https://git-lfs.github.com/spec/v1\noid sha256:${oid}\nsize ${payload.length}\n`;
  const spacedName = process.platform === 'win32' ? 'with space name.txt' : 'with space\tname.txt';
  for (const [path, bytes] of [['first.txt', 'same'], [spacedName, 'same'], ['asset.bin', pointer], ['copy.bin', pointer]]) writeFileSync(join(root, path), bytes);
  git('add', '.'); git('commit', '-qm', 'fixture');
  return { root, git, payload, oid, pointer };
}

test('distinguishes repeated checkout bytes from unique Git blobs and LFS objects', t => {
  const { root, git, payload, pointer } = fixture(t);
  const result = inspectRepository(root);
  assert.equal(result.source.commit, git('rev-parse', 'HEAD'));
  assert.equal(result.git.blobPaths, 4);
  assert.equal(result.git.uniqueBlobs, 2);
  assert.equal(result.git.checkoutBlobBytes, 8 + 2 * Buffer.byteLength(pointer));
  assert.equal(result.git.uniqueBlobBytes, 4 + Buffer.byteLength(pointer));
  assert.equal(result.lfs.pointerPaths, 2);
  assert.equal(result.lfs.uniqueObjects, 1);
  assert.equal(result.lfs.uniquePayloadBytes, payload.length);
  assert.equal(result.lfs.logicalCheckoutPayloadBytes, 2 * payload.length);
  assert.equal(result.lfs.verifiedWorktreeBytes, 0);
  assert.equal(result.lfs.readableUniqueBytes, 0);
  assert.equal(result.checkout.logicalBytesWithAllLfs, 8 + 2 * payload.length);
  assert.equal(result.checkout.measuredNetworkTransferBytes, null);
  assert.equal(result.officialCandidateBytes, null);
  assert.equal(result.source.trackedChanges, false);
});

test('authenticates materialized bytes and counts a shared OID once', t => {
  const { root, payload } = fixture(t);
  writeFileSync(join(root, 'asset.bin'), payload);
  const result = inspectRepository(root);
  assert.equal(result.lfs.readableUniqueBytes, payload.length);
  assert.equal(result.lfs.verifiedWorktreeBytes, payload.length);
  assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'verified');
  assert.equal(result.lfs.paths.find(x => x.path === 'copy.bin').worktree, 'pointer');
  assert.equal(result.source.trackedChanges, true);
});

test('reports corrupt, missing and cached objects without any network transfer', t => {
  const { root, oid, payload } = fixture(t);
  writeFileSync(join(root, 'asset.bin'), Buffer.alloc(payload.length, 1));
  rmSync(join(root, 'copy.bin'));
  const object = join(root, '.git/lfs/objects', oid.slice(0, 2), oid.slice(2, 4), oid);
  mkdirSync(join(object, '..'), { recursive: true }); writeFileSync(object, payload);
  const result = inspectRepository(root);
  assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'corrupt');
  assert.equal(result.lfs.paths.find(x => x.path === 'copy.bin').worktree, 'missing');
  assert.equal(result.lfs.objects[0].cache, 'verified');
  assert.equal(result.lfs.readableUniqueBytes, payload.length);
});

test('does not follow a replacement worktree symlink to classify an LFS asset', t => {
  if (process.platform === 'win32') return t.skip('symlink privilege is not assumed on Windows');
  const { root, payload } = fixture(t);
  writeFileSync(join(root, 'outside.bin'), payload); rmSync(join(root, 'asset.bin'));
  symlinkSync('outside.bin', join(root, 'asset.bin'));
  const result = inspectRepository(root);
  assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'symlink');
  assert.equal(result.lfs.readableUniqueBytes, 0);
});

test('does not follow a replacement LFS parent directory symlink', t => {
  if (process.platform === 'win32') return t.skip('symlink privilege is not assumed on Windows');
  const { root, git, payload, pointer } = fixture(t);
  mkdirSync(join(root, 'nested')); writeFileSync(join(root, 'nested/asset.bin'), pointer);
  git('add', '.'); git('commit', '-qm', 'nested asset');
  mkdirSync(join(root, 'other')); writeFileSync(join(root, 'other/asset.bin'), payload);
  rmSync(join(root, 'nested'), { recursive: true }); symlinkSync('other', join(root, 'nested'));
  const result = inspectRepository(root);
  assert.equal(result.lfs.paths.find(x => x.path === 'nested/asset.bin').worktree, 'symlink');
  assert.equal(result.lfs.readableUniqueBytes, 0);
});

test('rejects malformed pointers rather than quietly treating them as ordinary text', t => {
  const { root, git, pointer } = fixture(t);
  writeFileSync(join(root, 'asset.bin'), pointer.replace(/size \d+/, 'size 9007199254740992'));
  git('add', '.'); git('commit', '-qm', 'bad pointer');
  assert.throws(() => inspectRepository(root), /Invalid LFS pointer/);
});

test('rejects two declared sizes for the same OID', t => {
  const { root, git, pointer, payload } = fixture(t);
  writeFileSync(join(root, 'asset.bin'), pointer.replace(`size ${payload.length}`, `size ${payload.length + 1}`));
  git('add', '.'); git('commit', '-qm', 'inconsistent pointer');
  assert.throws(() => inspectRepository(root), /Conflicting LFS sizes/);
});

test('reads small binary Git blobs without UTF-8 conversion or false pointer detection', t => {
  const { root, git } = fixture(t);
  writeFileSync(join(root, 'binary.bin'), Buffer.from([0xff, 0xfe, 0x00, 0x80]));
  git('add', '.'); git('commit', '-qm', 'binary blob');
  const result = inspectRepository(root);
  assert.equal(result.git.blobPaths, 5);
  assert.equal(result.lfs.pointerPaths, 2);
});

function buildFixture(t) {
  const result = fixture(t);
  writeFileSync(join(result.root, '.gitignore'), 'build/\n');
  mkdirSync(join(result.root, 'scripts'));
  for (const [name, index, output] of [['build-lua-data.mjs', 3, 'data.lua'], ['build-ui.mjs', 2, 'ui.lua'], ['build-ui-theme.mjs', 4, 'theme.lua']]) {
    const uiOutputs = requiredBuildOutputs.filter(path => !['abyss_data.lua', 'abyss_theme.lua'].includes(path));
    const body = `import {mkdirSync,writeFileSync} from 'node:fs'; import {dirname,join} from 'node:path'; const arg=process.argv[${index}]; const out=${index === 2 ? `join(arg, '${output}')` : 'arg'}; mkdirSync(dirname(out),{recursive:true}); writeFileSync(out,'stable ${name}');` + (index === 2 ? `for(const file of ${JSON.stringify(uiOutputs)})writeFileSync(join(arg,file),'stable UI');` : '');
    writeFileSync(join(result.root, 'scripts', name), body);
  }
  result.git('add', '.'); result.git('commit', '-qm', 'builders');
  return result;
}

test('measures fresh-output and repeated-output builds with identical byte receipts', t => {
  const { root } = buildFixture(t);
  const report = measureBuilds(root, { rounds: 2 });
  assert.equal(report.status, 'passed');
  assert.equal(report.pairs.length, 2);
  assert.match(report.coldDefinition, /OS.*not/i);
  for (const pair of report.pairs) {
    assert.equal(pair.cold.steps.length, 3);
    assert.equal(pair.warm.steps.length, 3);
    assert.equal(pair.identicalOutputs, true);
    assert.ok(pair.cold.wallMs > 0);
    assert.deepEqual(pair.cold.outputs, pair.warm.outputs);
  }
  assert.ok(report.summary.cold.p95Ms >= report.summary.cold.p50Ms);
});

test('records a failed build, stops the pair and never calls it a successful sample', t => {
  const { root } = buildFixture(t);
  writeFileSync(join(root, 'scripts/build-ui.mjs'), 'process.stderr.write("intentional build failure");process.exit(7);');
  const report = measureBuilds(root, { rounds: 2 });
  assert.equal(report.status, 'failed');
  assert.equal(report.pairs.length, 1);
  assert.equal(report.pairs[0].cold.steps[1].exitCode, 7);
  assert.match(report.pairs[0].cold.steps[1].stderr, /intentional build failure/);
  assert.equal(report.pairs[0].warm, null);
  assert.equal(report.summary, null);
});

test('rejects cold/warm output drift instead of reporting a performance comparison', t => {
  const { root } = buildFixture(t);
  const script = join(root, 'scripts/build-ui.mjs');
  writeFileSync(script, readFileSync(script, 'utf8') + `writeFileSync(join(process.argv[2],'ui.lua'),String(Date.now()));`);
  const report = measureBuilds(root, { rounds: 1 });
  assert.equal(report.pairs[0].cold.status, 'passed');
  assert.equal(report.pairs[0].warm.status, 'passed');
  assert.equal(report.status, 'failed');
  assert.equal(report.pairs[0].identicalOutputs, false);
  assert.equal(report.summary, null);
});

test('does not accept zero, fractional or excessive measurement rounds', t => {
  const { root } = buildFixture(t);
  for (const rounds of [0, -1, 1.5, 11]) assert.throws(() => measureBuilds(root, { rounds }), /rounds/);
});

test('rejects source changes during paired builds even if generated bytes remain equal', t => {
  const { root } = buildFixture(t);
  const script = join(root, 'scripts/build-ui.mjs');
  writeFileSync(script, readFileSync(script, 'utf8') + `writeFileSync('first.txt','changed input');`);
  const report = measureBuilds(root, { rounds: 1 });
  assert.equal(report.pairs[0].identicalOutputs, true);
  assert.notEqual(report.source.inputDigest, report.finalInputDigest);
  assert.equal(report.status, 'failed');
  assert.equal(report.summary, null);
});

test('rejects successful commands that produce no files', t => {
  const { root } = buildFixture(t);
  for (const name of ['build-lua-data.mjs', 'build-ui.mjs', 'build-ui-theme.mjs']) writeFileSync(join(root, 'scripts', name), '');
  const report = measureBuilds(root, { rounds: 1 });
  assert.equal(report.status, 'failed');
  assert.equal(report.summary, null);
});

test('rejects a symlink build directory before writing any output', t => {
  if (process.platform === 'win32') return t.skip('symlink privilege is not assumed on Windows');
  const { root } = buildFixture(t);
  mkdirSync(join(root, 'elsewhere')); symlinkSync('elsewhere', join(root, 'build'));
  assert.throws(() => measureBuilds(root, { rounds: 1 }), /symlink/);
});
