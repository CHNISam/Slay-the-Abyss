// All candidate files are harmless temporary text. An impossible source ref
// stops the real CLI at its Git prerequisite, before any MCP imports.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, symlinkSync, rmSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { auditNativeCandidate } from '../scripts/audit-native-candidate.mjs';

async function fixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-audit-paths-'));
  const options = (candidate, name = 'evidence') => ({ source: '0'.repeat(40), candidate, output: join(root, name) });
  try { await run(root, options); } finally { rmSync(root, { recursive: true, force: true }); }
}
function directoryLink(target, alias) {
  symlinkSync(target, alias, process.platform === 'win32' ? 'junction' : 'dir');
}
function stoppedBeforeMcp(report) {
  assert.equal(report.ok, false);
  assert.equal(report.issues[0].code, 'AUDIT_ERROR');
  assert.match(report.issues[0].detail, /^git:/);
  for (const field of ['officialImport', 'playtest', 'audio']) assert.equal(report[field], 'NOT_TESTED');
}

test('candidate symlink/.. retains filesystem identity and hash before lexical normalization', async () => fixture(async (root, options) => {
  const physical = join(root, 'physical'); mkdirSync(join(physical, 'nested'), { recursive: true });
  const target = join(physical, 'candidate.txt');
  writeFileSync(target, 'intended candidate'); writeFileSync(join(root, 'candidate.txt'), 'lexical decoy');
  directoryLink(join(physical, 'nested'), join(root, 'alias'));
  const raw = join(root, 'alias') + '/../candidate.txt';
  // The host filesystem, not path.resolve or a POSIX assumption, selects the
  // file. On Linux this is the physical parent, not the lexical decoy.
  const selected = realpathSync.native(raw);
  const expectedHash = createHash('sha256').update(readFileSync(raw)).digest('hex');
  for (const [index, spelling] of [raw, relative(process.cwd(), root) + '/alias/../candidate.txt'].entries()) {
    const report = await auditNativeCandidate(options(spelling, `evidence-${index}`));
    stoppedBeforeMcp(report);
    assert.equal(report.candidate.path, selected);
    assert.equal(report.candidate.sha256Before, expectedHash);
    assert.equal(report.candidate.sha256After, report.candidate.sha256Before);
  }
}));

test('direct and aliased official-save directory components reject before creating evidence', async () => fixture(async (root, options) => {
  const save = join(root, 'Beyond_Local_Save_Level'); mkdirSync(save);
  const candidate = join(save, 'dummy.txt'); writeFileSync(candidate, 'not a save binary');
  directoryLink(save, join(root, 'directory-alias'));
  const paths = [candidate, join(root, 'directory-alias', 'dummy.txt'), relative(process.cwd(), save) + '/dummy.txt'];
  for (const [index, path] of paths.entries()) {
    const request = options(path, `rejected-${index}`);
    await assert.rejects(auditNativeCandidate(request), /exported candidate copy/);
    assert.equal(existsSync(request.output), false);
  }
  assert.equal(readFileSync(candidate, 'utf8'), 'not a save binary');
}));

test('file symlink to an official-save directory rejects before creating evidence', async t => fixture(async (root, options) => {
  const save = join(root, 'Beyond_Local_Save_Level'); mkdirSync(save);
  const candidate = join(save, 'dummy.txt'); writeFileSync(candidate, 'not a save binary');
  const alias = join(root, 'file-alias');
  try { symlinkSync(candidate, alias, 'file'); }
  catch (error) {
    if (!['EPERM', 'EACCES', 'ENOTSUP', 'ENOSYS'].includes(error.code)) throw error;
    t.skip(`Host cannot create file symlinks: ${error.code}`);
    return;
  }
  const request = options(alias);
  await assert.rejects(auditNativeCandidate(request), /exported candidate copy/);
  assert.equal(existsSync(request.output), false);
  assert.equal(readFileSync(candidate, 'utf8'), 'not a save binary');
}));

test('raw official-save spelling stays forbidden even if an alias escapes the directory', async () => fixture(async (root, options) => {
  const exported = join(root, 'exported'); mkdirSync(exported); writeFileSync(join(exported, 'dummy.txt'), 'exported text');
  directoryLink(exported, join(root, 'Beyond_Local_Save_Level'));
  const request = options(join(root, 'Beyond_Local_Save_Level', 'dummy.txt'));
  await assert.rejects(auditNativeCandidate(request), /exported candidate copy/);
  assert.equal(existsSync(request.output), false);
}));

test('non-file candidate rejects before output while similarly named export directories remain allowed', async () => fixture(async (root, options) => {
  const candidate = join(root, 'Beyond_Local_Save_Level-exported'); mkdirSync(candidate);
  await assert.rejects(auditNativeCandidate(options(candidate)), /regular file/);
  assert.equal(existsSync(options(candidate).output), false);
  const file = join(candidate, 'dummy.txt'); writeFileSync(file, 'valid export spelling');
  stoppedBeforeMcp(await auditNativeCandidate(options(file)));
}));

test('output symlink/.. writes only to the filesystem-selected new directory', async () => fixture(async (root, options) => {
  const physical = join(root, 'physical'); mkdirSync(join(physical, 'nested'), { recursive: true });
  directoryLink(join(physical, 'nested'), join(root, 'alias'));
  const candidate = join(root, 'candidate.txt'); writeFileSync(candidate, 'exported text');
  const request = options(candidate);
  request.output = join(root, 'alias') + '/../new/evidence';
  const selectedParent = realpathSync.native(join(root, 'alias') + '/..');
  stoppedBeforeMcp(await auditNativeCandidate(request));
  assert.equal(existsSync(join(selectedParent, 'new', 'evidence', 'audit.json')), true);
  if (selectedParent !== realpathSync.native(root)) assert.equal(existsSync(join(root, 'new')), false);
}));

test('canonical output identity preserves existing evidence and rejects unresolved parent traversal', async () => fixture(async (root, options) => {
  const physical = join(root, 'physical'); mkdirSync(join(physical, 'nested'), { recursive: true });
  directoryLink(join(physical, 'nested'), join(root, 'alias'));
  const candidate = join(root, 'candidate.txt'); writeFileSync(candidate, 'exported text');
  const selectedParent = realpathSync.native(join(root, 'alias') + '/..');
  const existing = join(selectedParent, 'evidence'); mkdirSync(existing); writeFileSync(join(existing, 'sentinel'), 'keep');
  const request = options(candidate);
  request.output = join(root, 'alias') + '/../evidence';
  await assert.rejects(auditNativeCandidate(request), /new directory/);
  assert.equal(readFileSync(join(existing, 'sentinel'), 'utf8'), 'keep');
  assert.equal(existsSync(join(existing, 'audit.json')), false);
  if (selectedParent !== realpathSync.native(root)) assert.equal(existsSync(join(root, 'evidence')), false);
  request.output = root + '/missing/../unresolved-evidence';
  // Some hosts resolve missing/.. themselves. Reject only traversal still
  // unresolved by the native filesystem, never invent a lexical destination.
  if (existsSync(root + '/missing/..')) {
    stoppedBeforeMcp(await auditNativeCandidate(request));
    assert.equal(existsSync(join(realpathSync.native(root + '/missing/..'), 'unresolved-evidence', 'audit.json')), true);
  } else {
    await assert.rejects(auditNativeCandidate(request), /parent traversal/);
    assert.equal(existsSync(join(root, 'unresolved-evidence')), false);
  }
}));

test('CLI report link names the actual canonical evidence destination', async () => fixture(async root => {
  const physical = join(root, 'physical'); mkdirSync(join(physical, 'nested'), { recursive: true });
  directoryLink(join(physical, 'nested'), join(root, 'alias'));
  const candidate = join(root, 'candidate.txt'); writeFileSync(candidate, 'exported text');
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/audit-native-candidate.mjs', import.meta.url)),
    '--source', '0'.repeat(40), '--candidate', candidate, '--output', join(root, 'alias') + '/../evidence'], { encoding: 'utf8' });
  assert.equal(result.status, 1, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.issues[0].code, 'AUDIT_ERROR');
  assert.equal(report.report, join(realpathSync.native(join(root, 'alias') + '/..'), 'evidence', 'audit.json'));
  assert.equal(existsSync(report.report), true);
}));
