import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync, lstatSync, realpathSync } from 'node:fs';
import { join, resolve, relative, isAbsolute, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync, spawnSync } from 'node:child_process';
import { inspectRepository, measureBuilds, requiredBuildOutputs } from '../scripts/repository-costs.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture(t, payload = Buffer.from('verified asset bytes')) {
  const root = realpathSync.native(mkdtempSync(join(tmpdir(), 'abyss-repo-cost-test-')));
  // All child Git calls, including inspectRepository, inherit only fixture configuration.
  const inheritedGit = Object.fromEntries(Object.entries(process.env).filter(([key]) => key.startsWith('GIT_')));
  for (const key of Object.keys(inheritedGit)) delete process.env[key];
  const globalConfig = join(root, '.git/empty-global-config');
  process.env.GIT_CONFIG_GLOBAL = globalConfig;
  process.env.GIT_CONFIG_NOSYSTEM = '1';
  t.after(() => {
    for (const key of Object.keys(process.env)) if (key.startsWith('GIT_')) delete process.env[key];
    Object.assign(process.env, inheritedGit);
  });
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  git('init', '-q'); git('config', 'core.autocrlf', 'false');
  git('config', 'user.email', 'cost-test@example.invalid'); git('config', 'user.name', 'Cost test');
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

test('recognizes intact LFS pointers whose byte length equals the payload size', t => {
  const { root, oid, payload, pointer } = fixture(t, Buffer.alloc(128, 42));
  assert.equal(Buffer.byteLength(pointer), payload.length);
  const object = join(root, '.git/lfs/objects', oid.slice(0, 2), oid.slice(2, 4), oid);
  mkdirSync(join(object, '..'), { recursive: true }); writeFileSync(object, pointer);
  const result = inspectRepository(root);
  assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'pointer');
  assert.equal(result.lfs.paths.find(x => x.path === 'copy.bin').worktree, 'pointer');
  assert.equal(result.lfs.objects[0].cache, 'pointer');
  assert.equal(result.lfs.verifiedWorktreeBytes, 0);
  assert.equal(result.lfs.readableUniqueBytes, 0);
});

test('authenticates real payload bytes even when they form a valid LFS pointer', t => {
  const payload = Buffer.from(`version https://git-lfs.github.com/spec/v1\noid sha256:${hash(Buffer.alloc(128, 42))}\nsize 128\n`);
  const { root, oid, pointer } = fixture(t, payload);
  assert.equal(payload.length, Buffer.byteLength(pointer));
  writeFileSync(join(root, 'asset.bin'), payload);
  const object = join(root, '.git/lfs/objects', oid.slice(0, 2), oid.slice(2, 4), oid);
  mkdirSync(join(object, '..'), { recursive: true }); writeFileSync(object, payload);
  const result = inspectRepository(root);
  assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'verified');
  assert.equal(result.lfs.objects[0].cache, 'verified');
  assert.equal(result.lfs.verifiedWorktreeBytes, payload.length);
  assert.equal(result.lfs.readableUniqueBytes, payload.length);
});

for (const [name, replacement] of [
  ['a mismatched declared size', ({ pointer, payload }) => pointer.replace(`size ${payload.length}`, `size ${payload.length + 1}`)],
  ['a mismatched OID', ({ pointer, oid }) => pointer.replace(oid, '0'.repeat(64))],
  ['malformed pointer syntax', ({ pointer, payload }) => pointer.replace(`size ${payload.length}`, `size 0${payload.length}`)],
]) {
  test(`reports ${name} as corrupt in the worktree and cache`, t => {
    const data = fixture(t), { root, oid } = data;
    const bytes = replacement(data);
    writeFileSync(join(root, 'asset.bin'), bytes);
    const object = join(root, '.git/lfs/objects', oid.slice(0, 2), oid.slice(2, 4), oid);
    mkdirSync(join(object, '..'), { recursive: true }); writeFileSync(object, bytes);
    const result = inspectRepository(root);
    assert.equal(result.lfs.paths.find(x => x.path === 'asset.bin').worktree, 'corrupt');
    assert.equal(result.lfs.objects[0].cache, 'corrupt');
    assert.equal(result.lfs.verifiedWorktreeBytes, 0);
    assert.equal(result.lfs.readableUniqueBytes, 0);
  });
}

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

// The installed Git LFS implementation is the storage-path oracle; clean is local-only.
function containedCachePath(root, path) {
  const inside = candidate => {
    const rel = relative(root, candidate);
    assert.ok(rel && rel !== '..' && !rel.startsWith(`..${process.platform === 'win32' ? '\\' : '/'}`) && !isAbsolute(rel),
      `Cache mutation escapes fixture: ${candidate}`);
  };
  path = resolve(path); inside(path);
  let ancestor = path;
  while (!lstatSync(ancestor, { throwIfNoEntry: false })) ancestor = dirname(ancestor);
  const actualAncestor = realpathSync.native(ancestor);
  if (actualAncestor !== root) inside(actualAncestor);
  return path;
}
test('LFS mutation guard canonicalizes existing paths and rejects sibling and junction escapes', t => {
  const root = realpathSync.native(mkdtempSync(join(tmpdir(), 'abyss-lfs-guard-')));
  const external = realpathSync.native(mkdtempSync(join(tmpdir(), 'abyss-lfs-guard-external-')));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  t.after(() => rmSync(external, { recursive: true, force: true }));
  assert.equal(containedCachePath(root, join(root, 'new/cache')), join(root, 'new/cache'));
  assert.throws(() => containedCachePath(root, root), /escapes fixture/);
  assert.throws(() => containedCachePath(root, root + '-sibling/cache'), /escapes fixture/);
  const link = join(root, 'alias');
  symlinkSync(external, link, process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => containedCachePath(root, join(link, 'new/cache')), /escapes fixture/);
});
const hasGitLfs = spawnSync('git', ['lfs', 'version'], { stdio: 'ignore' }).status === 0;
const actualGitLfsNames = [];
for (const linked of [false, true]) {
  for (const storage of ['default', 'empty', 'relative', 'absolute', 'worktree override']) {
    if (!linked && storage === 'worktree override') continue;
    const name = `authenticates actual Git LFS ${storage} storage in ${linked ? 'linked' : 'ordinary'} worktree`;
    actualGitLfsNames.push(name);
    test(name,
      { skip: !hasGitLfs && 'git-lfs is not installed' }, t => {
        const { root, git, oid, payload, pointer } = fixture(t);
        const cwd = linked ? join(root, 'linked') : root;
        if (linked) git('worktree', 'add', '--detach', cwd, 'HEAD');
        const run = (args, input) => execFileSync('git', args, { cwd, input, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
        if (storage === 'empty') git('config', 'lfs.storage', '');
        if (storage === 'relative') git('config', 'lfs.storage', '../relative cache');
        if (storage === 'absolute') git('config', 'lfs.storage', join(root, 'absolute cache'));
        if (storage === 'worktree override') {
          git('config', 'lfs.storage', join(root, 'unused common cache'));
          git('config', 'extensions.worktreeConfig', 'true');
          run(['config', '--worktree', 'lfs.storage', 'worktree cache']);
        }
        const media = run(['lfs', 'env']).split('\n').find(line => line.startsWith('LocalMediaDir=')).slice('LocalMediaDir='.length);
        const safe = path => containedCachePath(root, path);
        safe(media); safe(dirname(media));
        const object = safe(join(media, oid.slice(0, 2), oid.slice(2, 4), oid));
        assert.equal(run(['lfs', 'clean', '--', 'asset.bin'], payload), pointer.trim());
        assert.deepEqual(readFileSync(object), payload);
        // Invoke below the checkout root too: Git tree paths remain root-relative.
        const nested = join(cwd, 'nested'); mkdirSync(nested);
        function check(state, bytes) {
          for (const directory of [cwd, nested]) {
            const report = inspectRepository(directory);
            assert.equal(report.lfs.objects[0].cache, state);
            assert.equal(report.lfs.readableUniqueBytes, bytes);
            assert.equal(report.lfs.verifiedWorktreeBytes, 0);
            assert.ok(report.lfs.paths.every(item => item.worktree === 'pointer'));
          }
        }
        check('verified', payload.length);
        writeFileSync(safe(object), Buffer.alloc(payload.length, 1)); check('corrupt', 0);
        writeFileSync(safe(object), Buffer.concat([payload, Buffer.from('extra')])); check('corrupt', 0);
        writeFileSync(safe(object), pointer); check('pointer', 0);
        rmSync(safe(object));
        // Correct bytes at the old/worktree-private or unconfigured path are not evidence.
        const decoy = resolve(cwd, run(['rev-parse', '--git-path', `lfs/objects/${oid.slice(0, 2)}/${oid.slice(2, 4)}/${oid}`]));
        if (resolve(decoy) !== resolve(object)) {
          mkdirSync(safe(join(decoy, '..')), { recursive: true }); writeFileSync(safe(decoy), payload);
        }
        check('missing', 0);
        if (process.platform !== 'win32') {
          const target = join(root, 'outside-payload'); writeFileSync(safe(target), payload);
          symlinkSync(safe(target), safe(object)); check('symlink', 0); rmSync(safe(object));
          const external = join(root, 'outside-objects');
          mkdirSync(safe(join(external, oid.slice(0, 2), oid.slice(2, 4))), { recursive: true });
          writeFileSync(safe(join(external, oid.slice(0, 2), oid.slice(2, 4), oid)), payload);
          rmSync(safe(media), { recursive: true }); symlinkSync(safe(external), safe(media)); check('symlink', 0);
        }
      });
  }
}

test('LFS fixtures preserve caches named by inherited global and command configuration',
  { skip: !hasGitLfs && 'git-lfs is not installed' }, t => {
    const external = realpathSync.native(mkdtempSync(join(tmpdir(), 'abyss-lfs-external-test-')));
    t.after(() => rmSync(external, { recursive: true, force: true }));
    const payload = Buffer.from('verified asset bytes'), oid = hash(payload);
    const media = join(external, 'shared/objects');
    const object = join(media, oid.slice(0, 2), oid.slice(2, 4), oid);
    mkdirSync(dirname(object), { recursive: true }); writeFileSync(object, payload);
    const sentinel = join(media, 'sentinel'); writeFileSync(sentinel, 'keep shared cache');
    const config = join(external, 'global-config');
    execFileSync('git', ['config', '--file', config, 'lfs.storage', join(external, 'shared')]);
    const childEnv = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('NODE_TEST_') && !key.startsWith('GIT_')));
    assert.equal(actualGitLfsNames.length, 9);
    for (const commandConfig of [{}, { GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'lfs.storage', GIT_CONFIG_VALUE_0: join(external, 'shared') }]) {
      // Retain all nine cases per inherited configuration and the original child deadline.
      // Three-case children fit Windows Git startup cost without retrying or skipping cases.
      for (let i = 0; i < actualGitLfsNames.length; i += 3) {
        const names = actualGitLfsNames.slice(i, i + 3);
        const pattern = `^(?:${names.join('|')})$`;
        const output = execFileSync(process.execPath, ['--test', '--test-reporter=spec', `--test-name-pattern=${pattern}`, 'tests/repository-costs.test.mjs'], {
          cwd: resolve(import.meta.dirname, '..'), timeout: 30000, stdio: 'pipe', encoding: 'utf8',
          env: { ...childEnv, GIT_CONFIG_GLOBAL: config, GIT_CONFIG_SYSTEM: config, ...commandConfig },
        });
        assert.match(output, /pass 3(?:\s|$)/);
        assert.deepEqual(readFileSync(object), payload);
        assert.equal(readFileSync(sentinel, 'utf8'), 'keep shared cache');
      }
    }
    assert.throws(() => containedCachePath(join(external, 'fixture'), media), /escapes fixture/);
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
    assert.equal(pair.matchesBaseline, true);
    assert.deepEqual(pair.cold.outputs, report.pairs[0].cold.outputs);
    assert.ok(pair.cold.wallMs > 0);
    assert.deepEqual(pair.cold.outputs, pair.warm.outputs);
  }
  assert.equal(report.summary.cold.count, 2);
  assert.equal(report.summary.warm.count, 2);
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

test('rejects cross-round output drift even when each cold/warm pair agrees', t => {
  const { root } = buildFixture(t);
  const script = join(root, 'scripts/build-ui.mjs');
  writeFileSync(script, readFileSync(script, 'utf8') + `writeFileSync(join(process.argv[2],'ui.lua'),process.argv[2].split(/[\\\\/]/).at(-1));`);
  const report = measureBuilds(root, { rounds: 2 });
  assert.equal(report.pairs.length, 2);
  for (const pair of report.pairs) {
    assert.equal(pair.cold.status, 'passed');
    assert.equal(pair.warm.status, 'passed');
    assert.equal(pair.identicalOutputs, true);
    assert.deepEqual(pair.cold.outputs, pair.warm.outputs);
    assert.equal(pair.cold.outputs.find(file => file.path === 'ui.lua').sha256, hash(`pair-${pair.round}`));
  }
  assert.notDeepEqual(report.pairs[0].cold.outputs, report.pairs[1].cold.outputs);
  assert.equal(report.source.inputDigest, report.finalInputDigest);
  assert.equal(report.status, 'failed');
  assert.equal(report.summary, null);
  assert.equal(report.pairs[0].matchesBaseline, true);
  assert.equal(report.pairs[1].matchesBaseline, false);
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
