import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, symlinkSync, rmSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, isAbsolute } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

function fixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-graph-audit-paths-'));
  try { run(root); } finally {
    const inside = relative(realpathSync.native(tmpdir()), realpathSync.native(root));
    assert(!isAbsolute(inside) && !inside.startsWith('..') && inside.startsWith('abyss-graph-audit-paths-'));
    rmSync(root, { recursive: true, force: true });
  }
}
function invoke(candidate, output) {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/audit-native-graph-payload.mjs', import.meta.url)),
    '--source', '0'.repeat(40), '--candidate', candidate, '--output', output], { encoding: 'utf8' });
  assert.equal(result.status, 1, result.stderr);
  return JSON.parse(result.stdout);
}
function directoryLink(target, alias) {
  symlinkSync(target, alias, process.platform === 'win32' ? 'junction' : 'dir');
}

test('explicit graph auditor rejects official-save directory aliases before creating output', () => fixture(root => {
  const official = join(root, 'Beyond_Local_Save_Level'); mkdirSync(official);
  const candidate = join(official, 'harmless.txt'); writeFileSync(candidate, 'not a game save');
  const alias = join(root, 'export-looking-alias'); directoryLink(official, alias);
  const output = join(root, 'must-not-be-created');
  const report = invoke(join(alias, 'harmless.txt'), output);
  assert.match(report.issues[0].detail, /exported candidate/);
  assert.equal(existsSync(output), false);
  assert.equal(readFileSync(candidate, 'utf8'), 'not a game save');
}));

test('explicit graph auditor preserves raw filesystem-selected candidate and evidence paths', () => fixture(root => {
  const physical = join(root, 'physical'); mkdirSync(join(physical, 'nested'), { recursive: true });
  directoryLink(join(physical, 'nested'), join(root, 'alias'));
  writeFileSync(join(physical, 'candidate.txt'), 'physical candidate');
  writeFileSync(join(root, 'candidate.txt'), 'lexical decoy');
  const rawCandidate = join(root, 'alias') + '/../candidate.txt';
  const rawOutput = join(root, 'alias') + '/../new/evidence';
  const outputParent = realpathSync.native(join(root, 'alias') + '/..');
  const report = invoke(rawCandidate, rawOutput);
  assert.match(report.issues[0].detail, /^git:/, 'fake source stops before loading any MCP tool');
  assert.equal(report.candidate.path, realpathSync.native(rawCandidate));
  assert.equal(existsSync(join(outputParent, 'new', 'evidence', 'graph-payload-audit.json')), true);
  assert.equal(readFileSync(rawCandidate, 'utf8'), outputParent === realpathSync.native(root) ? 'lexical decoy' : 'physical candidate');
}));

test('explicit graph auditor rejects non-file input and preserves existing evidence', () => fixture(root => {
  const output = join(root, 'evidence');
  const report = invoke(root, output);
  assert.match(report.issues[0].detail, /regular file/);
  assert.equal(existsSync(output), false);
  mkdirSync(output); writeFileSync(join(output, 'sentinel'), 'keep');
  const candidate = join(root, 'candidate.txt'); writeFileSync(candidate, 'exported text');
  assert.match(invoke(candidate, output).issues[0].detail, /new directory/);
  assert.equal(readFileSync(join(output, 'sentinel'), 'utf8'), 'keep');
  assert.equal(existsSync(join(output, 'graph-payload-audit.json')), false);
}));
