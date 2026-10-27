import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, linkSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { loadReleaseNotes, parseChangelog, notesSha256, releaseSourceFiles, releaseBuildArgs } from '../scripts/release-notes.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { sourceInputs } from '../scripts/build-native-candidate.mjs';

const sourceIdentity = { sourceCommit: 'a'.repeat(40), sourceDirty: false };
const changelog = (id = '0.1.1', notes = '### 新增\n\n* 接入更新说明入口。') => `## [${id}](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.1.0...v${id}) (2026-10-27)\n\n${notes}\n`;
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-release-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'data/release'), { recursive: true });
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '0.1.0' }));
  writeFileSync(join(root, 'package-lock.json'), JSON.stringify({ version: '0.1.0', packages: { '': { version: '0.1.0' } } }));
  writeFileSync(join(root, '.release-please-manifest.json'), '{".":"0.1.0"}');
  writeFileSync(join(root, 'CHANGELOG.md'), '# 版本说明\n工程基线，无历史发布。\n');
  writeFileSync(join(root, 'data/release/publications.json'), '{"schemaVersion":1,"releases":[]}');
  const ledger = releases => writeFileSync(join(root, 'data/release/publications.json'), JSON.stringify({ schemaVersion: 1, releases }));
  const setVersion = id => {
    writeFileSync(join(root, 'package.json'), JSON.stringify({ version: id }));
    writeFileSync(join(root, 'package-lock.json'), JSON.stringify({ version: id, packages: { '': { version: id } } }));
    writeFileSync(join(root, '.release-please-manifest.json'), JSON.stringify({ '.': id }));
  };
  return { root, ledger, setVersion, load: options => loadReleaseNotes({ root, sourceIdentity, ...options }) };
}
function receipt(root, id = 'v0.1.1', extra = {}) {
  const notes = parseChangelog(readFileSync(join(root, 'CHANGELOG.md'), 'utf8')).get(id);
  writeFileSync(join(root, 'publication-evidence.txt'), 'Redacted real-publication evidence fixture.');
  return { version: id, sourceCommit: 'b'.repeat(40), publishedAt: '2026-10-27T21:00:00Z',
    workKey: 'alpha-test', workId: '123456789', artifactSha256: 'c'.repeat(64), notesSha256: notesSha256(notes),
    evidence: 'publication-evidence.txt', ...extra };
}

test('engineering baseline has version and source, no current notice or invented historical publication', t => {
  const f = fixture(t), result = f.load();
  assert.deepEqual(result, { schemaVersion: 1, build: { version: 'v0.1.0', workKey: 'alpha-test', ...sourceIdentity }, history: [] });
  assert.equal('currentNotice' in result, false);
  assert.deepEqual(JSON.parse(readFileSync('data/release/publications.json')), { schemaVersion: 1, releases: [] });
  const indexed = parseChangelog(readFileSync('CHANGELOG.md', 'utf8'));
  assert.ok(indexed.size >= 14, 'the checked-in backfilled versions must not disappear');
  assert.ok(indexed.has(`v${JSON.parse(readFileSync('package.json', 'utf8')).version}`),
    'the current code version must have visible notes');
});
test('unknown source is honestly omitted in a non-Git snapshot, never claimed clean', t => {
  const f = fixture(t), result = loadReleaseNotes({ root: f.root });
  assert.equal('sourceCommit' in result.build, false);
  assert.equal('sourceDirty' in result.build, false);
  assert.throws(() => loadReleaseNotes({ root: f.root, releaseCandidate: true }), /known source/);
});
test('prepared notes are opt-in current bundle copy, not a publication', t => {
  const f = fixture(t); f.setVersion('0.1.1'); writeFileSync(join(f.root, 'CHANGELOG.md'), changelog());
  assert.equal('currentNotice' in f.load(), false);
  const result = f.load({ releaseCandidate: true });
  assert.equal(result.currentNotice.version, 'v0.1.1');
  assert.equal(result.currentNotice.notesDate, '2026-10-27');
  assert.deepEqual(result.currentNotice.added, ['接入更新说明入口。']);
  assert.deepEqual(result.history, []);
  assert.throws(() => f.load({ releaseCandidate: true, sourceIdentity: { ...sourceIdentity, sourceDirty: true } }), /clean source/);
});

test('Alpha backfilled source versions remain browsable without fabricated publication receipts', t => {
  const f = fixture(t);
  f.setVersion('0.10.1');
  writeFileSync(join(f.root, 'CHANGELOG.md'),
    changelog('0.9.0', '### 新增\n\n* 加入角色。') +
    changelog('0.10.0', '### 新增\n\n* 加入公告。') +
    changelog('0.10.1', '### 修复\n\n* 修复战斗。'));
  const result = f.load();
  assert.deepEqual(result.history.map(x => x.version), ['v0.10.1', 'v0.10.0', 'v0.9.0']);
  assert.ok(result.history.every(x => x.versionDate === '2026-10-27'));
  assert.ok(result.history.every(x => !('publishedDate' in x)), 'source version dates are not release receipts');
  assert.deepEqual(f.load({ workKey: 'contest-2026' }).history, []);
  const candidate = f.load({ releaseCandidate: true });
  assert.equal(candidate.currentNotice.version, 'v0.10.1');
  assert.deepEqual(candidate.history.map(x => x.version), ['v0.10.0', 'v0.9.0']);
});

test('candidate requires exact package/lock/manifest/notes match and plain versions', t => {
  const f = fixture(t);
  assert.throws(() => f.load({ releaseCandidate: true }), /matching CHANGELOG/);
  for (const id of ['0.1.0-alpha.1', 'v0.1.0', '01.1.0', '1.0.0+meta']) {
    f.setVersion(id); assert.throws(() => f.load(), /plain/);
  }
  f.setVersion('0.1.1');
  for (const file of ['package-lock.json', '.release-please-manifest.json']) {
    const previous = readFileSync(join(f.root, file)); writeFileSync(join(f.root, file), '{}');
    assert.throws(() => f.load(), /versions must match/); writeFileSync(join(f.root, file), previous);
  }
});
test('upstream scope, issue/PR/commit links, breaking sections and long Unicode prose preserve all visible text', () => {
  const text = '完整保留'.repeat(70) + '😀';
  const source = changelog('0.2.0', `### ⚠ BREAKING CHANGES\n\n* **save:** 调整存档字段。\n  保留迁移说明。\n\n### 新增\n\n* **ui:** ${text} ([#123](https://github.com/CHNISam/Slay-the-Abyss/pull/123)) ([abcdef1](https://github.com/CHNISam/Slay-the-Abyss/commit/abcdef1234567)), closes [#12](https://github.com/CHNISam/Slay-the-Abyss/issues/12)\n\n### 修复\n\n* 不吞掉修复说明。`);
  const note = parseChangelog(source).get('v0.2.0');
  assert.deepEqual(note.improved, ['兼容性变更：save: 调整存档字段。 保留迁移说明。']);
  assert.deepEqual(note.added, [`ui: ${text} (#123), closes #12`]);
  assert.deepEqual(note.fixed, ['不吞掉修复说明。']);
});
test('Release-As/engineering-only batches may have no visible notes; no fake bullets are inserted', t => {
  const f = fixture(t); f.setVersion('1.0.0'); writeFileSync(join(f.root, 'CHANGELOG.md'), changelog('1.0.0', ''));
  assert.deepEqual(f.load({ releaseCandidate: true }).currentNotice,
    { version: 'v1.0.0', notesDate: '2026-10-27', added: [], improved: [], fixed: [] });
});
test('duplicate/ambiguous versions, suffixes, impossible dates and unsupported content fail visibly', () => {
  for (const source of [changelog() + changelog(), changelog('0.1.1-alpha.1'), changelog().replace('2026-10-27', '2026-02-30'),
    changelog('0.1.1', '### 未知内容\n\n* 不可丢失。'), changelog('0.1.1', '### 修复\n\n没有项目符号的正文。'),
    changelog('0.1.1', '### 新增\n\n* [外链](https://example.com)')]) assert.throws(() => parseChangelog(source));
});
test('real platform publication metadata stays receipt-confirmed and work-scoped in UTC+8', t => {
  const f = fixture(t); f.setVersion('0.1.2');
  writeFileSync(join(f.root, 'CHANGELOG.md'), changelog() + changelog('0.1.2'));
  const older = receipt(f.root, 'v0.1.1', { publishedAt: '2026-10-25T23:00:00+08:00' });
  const newer = receipt(f.root, 'v0.1.2');
  f.ledger([older, { ...newer, workKey: 'contest-2026', workId: '987654321' }, newer]);
  const result = f.load();
  assert.deepEqual(result.history.map(row => row.version), ['v0.1.2', 'v0.1.1']);
  assert.equal(result.history[0].publishedDate, '2026-10-28');
  assert.equal(result.history[0].sourceCommit, newer.sourceCommit);
  assert.equal(f.load({ workKey: 'contest-2026' }).history.length, 1);
  assert.deepEqual(f.load({ workKey: 'unpublished-work' }).history, []);
  f.ledger([newer, { ...newer, workKey: 'contest-2026', artifactSha256: 'e'.repeat(64) }]);
  assert.throws(() => f.load(), /Version reused for different content/);
});
test('receipts require real identity/time/evidence and frozen prose hash, including other works', t => {
  const f = fixture(t); writeFileSync(join(f.root, 'CHANGELOG.md'), changelog());
  const valid = receipt(f.root);
  for (const patch of [{ sourceCommit: 'a' }, { artifactSha256: '' }, { notesSha256: 'd'.repeat(64) }, { workId: '' },
    { publishedAt: '2026-10-27T08:00:00' }, { evidence: '' }, { evidence: 'missing.md' }, { evidence: '../escape.md' },
    { workKey: 'contest-2026', notesSha256: 'd'.repeat(64) }]) {
    f.ledger([{ ...valid, ...patch }]); assert.throws(() => f.load());
  }
  f.ledger([valid, valid]); assert.throws(() => f.load(), /Duplicate publication/);
  f.ledger([valid]); writeFileSync(join(f.root, 'CHANGELOG.md'), changelog('0.1.1', '### 新增\n\n* 偷改已发布文案。'));
  assert.throws(() => f.load(), /hash mismatch/);
  writeFileSync(join(f.root, 'CHANGELOG.md'), '# missing release block'); assert.throws(() => f.load(), /Missing CHANGELOG/);
});
test('published versions remain snapshot-readable but cannot build another release candidate under any work key', t => {
  const f = fixture(t); f.setVersion('0.1.1');
  writeFileSync(join(f.root, 'CHANGELOG.md'), changelog() + changelog('0.1.2'));
  const published = receipt(f.root); f.ledger([published]);
  assert.equal(f.load().history[0].version, 'v0.1.1', 'ordinary snapshots can display confirmed history');
  for (const workKey of ['alpha-test', 'contest-2026']) {
    assert.throws(() => f.load({ releaseCandidate: true, workKey,
      sourceIdentity: { sourceCommit: 'd'.repeat(40), sourceDirty: false } }), /Version already published/);
  }
  assert.throws(() => f.load({ releaseCandidate: true,
    sourceIdentity: { sourceCommit: published.sourceCommit, sourceDirty: false } }), /Version already published/);
  f.setVersion('0.1.2');
  const fresh = f.load({ releaseCandidate: true });
  assert.equal(fresh.currentNotice.version, 'v0.1.2');
  assert.deepEqual(fresh.history.map(row => row.version), ['v0.1.1']);
});
test('proposal workflow is manually dispatched, pinned, manifest-driven and cannot tag or release', () => {
  const config = JSON.parse(readFileSync('release-please-config.json'));
  assert.equal(config.packages['.']['release-type'], 'node');
  assert.equal(config['include-component-in-tag'], false); assert.equal(config['include-v-in-tag'], true);
  assert.equal(config['versioning'], 'default'); assert.equal(config['bump-minor-pre-major'], true);
  assert.equal(config['bump-patch-for-minor-pre-major'], false); assert.equal(config['draft-pull-request'], true);
  const workflow = readFileSync('.github/workflows/release-proposal.yml', 'utf8');
  assert.match(workflow, /on:\s*\n  workflow_dispatch:/); assert.doesNotMatch(workflow, /\n  (?:push|pull_request|release|schedule):/);
  assert.match(workflow, /release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7/);
  assert.match(workflow, /skip-github-release: true/); assert.doesNotMatch(workflow, /\n\s+release-type:/);
  assert.match(workflow, /target-branch: develop/); assert.doesNotMatch(workflow, /run:|master/);
  assert.deepEqual(releaseBuildArgs(['out', '--release-candidate', '--work-key=contest-2026']),
    { paths: ['out'], options: { releaseCandidate: true, workKey: 'contest-2026' } });
  assert.throws(() => releaseBuildArgs(['--publish']), /Unknown/);
});
test('native source inventory binds CHANGELOG, version manifest and release config', () => {
  const paths = sourceInputs(process.cwd()).map(row => row.path);
  for (const path of ['CHANGELOG.md', '.release-please-manifest.json', 'release-please-config.json', 'data/release/publications.json']) assert(paths.includes(path));
});
for (const mode of ['hardlink', 'symlink']) for (const input of [...releaseSourceFiles, 'publication-evidence.txt']) {
  test(`UI batch preflight protects ${mode} release input ${input}`, t => {
    const f = fixture(t); cpSync(resolve('data'), join(f.root, 'data'), { recursive: true });
    writeFileSync(join(f.root, 'CHANGELOG.md'), changelog()); f.ledger([receipt(f.root)]);
    mkdirSync(join(f.root, 'out'));
    const target = join(f.root, 'out/abyss_ui_templates.lua');
    try { if (mode === 'hardlink') linkSync(join(f.root, input), target); else symlinkSync(join(f.root, input), target, 'file'); }
    catch (error) { if (['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) { t.skip(error.code); return; } throw error; }
    const previous = readFileSync(join(f.root, input)), cwd = process.cwd();
    try { process.chdir(f.root); assert.throws(() => buildUI('out'), /Output must not overwrite an input file/); }
    finally { process.chdir(cwd); }
    assert.deepEqual(readFileSync(join(f.root, input)), previous);
    assert.deepEqual(readdirSync(join(f.root, 'out')), ['abyss_ui_templates.lua']);
  });
}
