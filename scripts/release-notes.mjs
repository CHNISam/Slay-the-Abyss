import { readFileSync, realpathSync, statSync } from 'node:fs';
import { resolve, relative, isAbsolute } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { validDate } from './evidence-files.mjs';

const plainVersion = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const sections = { 新增: 'added', 优化: 'improved', 修复: 'fixed' };
const json = file => JSON.parse(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
export const releaseSourceFiles = ['package.json', 'package-lock.json', '.release-please-manifest.json',
  'CHANGELOG.md', 'data/release/publications.json'];

export function releaseBuildArgs(args) {
  const paths = [], options = { releaseCandidate: false, workKey: 'alpha-test' };
  for (const arg of args) {
    if (arg === '--release-candidate') options.releaseCandidate = true;
    else if (arg.startsWith('--work-key=')) options.workKey = arg.slice('--work-key='.length);
    else if (arg.startsWith('--')) throw new Error(`Unknown build option: ${arg}`);
    else paths.push(arg);
  }
  return { paths, options };
}

function version(value, prefixed = true) {
  if (typeof value !== 'string' || value.length > 32 || !plainVersion.test(prefixed ? value.replace(/^v/, '') : value)
    || (prefixed && !value.startsWith('v'))) throw new Error(`Expected plain ${prefixed ? 'v' : ''}X.Y.Z version: ${value}`);
  return prefixed ? value : `v${value}`;
}
function date(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value ?? '') || !validDate(`${value}T00:00:00Z`)) throw new Error(`Invalid notes date: ${value}`);
  return value;
}
function bullet(line) {
  // Only Release Please's known scope, commit and issue/PR link syntax is removed.
  // Arbitrary Markdown or wrapped prose needs review rather than silent loss.
  const text = line.replace(/^\*\*([^*]+):\*\*\s*/, '$1: ')
    .replace(/\s*\(\[([a-f0-9]{7,40})\]\(https:\/\/github\.com\/[^\s/]+\/[^\s/]+\/commit\/[a-f0-9]{7,40}\)\)/g, '')
    .replace(/\[(#\d+)\]\(https:\/\/github\.com\/[^\s/]+\/[^\s/]+\/(?:pull|issues)\/\d+\)/g, '$1')
    .trim();
  if (!text || !text.isWellFormed() || /[\[\]`<>*\r\n]|[\u0000-\u001f\u007f]/.test(text)) throw new Error(`Unsupported release note markup: ${line}`);
  return text;
}

export function parseChangelog(source) {
  const notes = new Map();
  let current, section, breaking;
  for (const raw of source.replace(/^\uFEFF/, '').split(/\r?\n/)) {
    if (/^##\s/.test(raw)) {
      const heading = raw.match(/^## (?:\[(v?\d+\.\d+\.\d+)\]\(https:\/\/github\.com\/[^\s)]+\)|v?(\d+\.\d+\.\d+)) \((\d{4}-\d{2}-\d{2})\)$/);
      if (!heading) throw new Error(`Unsupported or ambiguous version heading: ${raw}`);
      const id = version(`v${(heading[1] ?? heading[2]).replace(/^v/, '')}`);
      if (notes.has(id)) throw new Error(`Duplicate version heading: ${id}`);
      current = { version: id, notesDate: date(heading[3]), added: [], improved: [], fixed: [] };
      notes.set(id, current); section = undefined; breaking = false;
    } else if (current && raw.trim()) {
      const title = raw.match(/^### (.+)$/);
      if (title) {
        breaking = /^⚠\uFE0F? BREAKING CHANGES$/.test(title[1]);
        section = breaking ? 'improved' : sections[title[1]];
        if (!section) throw new Error(`Unsupported visible release section: ${title[1]}`);
      } else {
        const item = raw.match(/^[*-] (.+)$/);
        if (item && section) current[section].push(`${breaking ? '兼容性变更：' : ''}${bullet(item[1])}`);
        else if (/^\s{2,}\S/.test(raw) && section && current[section].length) {
          current[section][current[section].length - 1] += ` ${bullet(raw.trim())}`;
        } else throw new Error(`Unsupported release note line: ${raw}`);
      }
    }
  }
  return notes;
}

// Stable UTF-8 JSON with this exact field order; dates and normalized visible prose are included.
export const notesSha256 = note => createHash('sha256').update(JSON.stringify({ version: note.version,
  notesDate: note.notesDate, added: note.added, improved: note.improved, fixed: note.fixed })).digest('hex');

export function gitSourceIdentity(root = process.cwd()) {
  const commit = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' });
  const dirty = spawnSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' });
  if (commit.status !== 0 || dirty.status !== 0 || !/^[a-f0-9]{40}$/.test(commit.stdout.trim())) return {};
  return { sourceCommit: commit.stdout.trim(), sourceDirty: Boolean(dirty.stdout.trim()) };
}

function evidencePath(root, evidence) {
  if (typeof evidence !== 'string' || !evidence || evidence.includes('\\') || isAbsolute(evidence)
    || evidence.split('/').some(part => !part || part === '.' || part === '..') || /[\u0000-\u001f]/.test(evidence)) {
    throw new Error('Publication receipt requires a repository evidence path');
  }
  let path;
  try { path = realpathSync(resolve(root, evidence)); }
  catch { throw new Error(`Missing publication evidence: ${evidence}`); }
  const rel = relative(realpathSync(root), path);
  if (isAbsolute(rel) || rel === '..' || rel.startsWith('../') || rel.startsWith('..\\') || !statSync(path).isFile()
    || statSync(path).size === 0) throw new Error(`Invalid publication evidence: ${evidence}`);
  return path;
}

export function releaseInputPaths(root = process.cwd()) {
  const ledger = json(resolve(root, 'data/release/publications.json'));
  if (ledger.schemaVersion !== 1 || !Array.isArray(ledger.releases)) throw new Error('Invalid publication ledger');
  return [...releaseSourceFiles.map(file => resolve(root, file)),
    ...ledger.releases.map(row => evidencePath(root, row.evidence))];
}

export function loadReleaseNotes({ root = process.cwd(), workKey = 'alpha-test', releaseCandidate = false,
  sourceIdentity = gitSourceIdentity(root) } = {}) {
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(workKey)) throw new Error('Invalid workKey');
  const { sourceCommit, sourceDirty } = sourceIdentity;
  if (releaseCandidate && (!/^[a-f0-9]{40}$/.test(sourceCommit ?? '') || typeof sourceDirty !== 'boolean')) throw new Error('Release candidate requires a known source identity');
  if (releaseCandidate && sourceDirty) throw new Error('Release candidate requires a clean source checkout');
  const pkg = json(resolve(root, 'package.json')), lock = json(resolve(root, 'package-lock.json'));
  const manifest = json(resolve(root, '.release-please-manifest.json'));
  const id = version(pkg.version, false);
  if (lock.version !== pkg.version || lock.packages?.['']?.version !== pkg.version || manifest['.'] !== pkg.version) {
    throw new Error('Package, package-lock and Release Please manifest versions must match');
  }
  const notes = parseChangelog(readFileSync(resolve(root, 'CHANGELOG.md'), 'utf8'));
  const ledger = json(resolve(root, 'data/release/publications.json'));
  if (ledger.schemaVersion !== 1 || !Array.isArray(ledger.releases)) throw new Error('Invalid publication ledger');
  const seen = new Set(), bindings = new Map();
  const confirmed = ledger.releases.map(row => {
    const recordVersion = version(row.version), key = `${row.workKey}/${recordVersion}`;
    if (typeof row.workKey !== 'string' || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(row.workKey)
      || typeof row.workId !== 'string' || !row.workId.trim() || /[\u0000-\u001f\u007f]/.test(row.workId)
      || !/^[a-f0-9]{40}$/.test(row.sourceCommit ?? '') || !validDate(row.publishedAt)
      || !/^[a-f0-9]{64}$/.test(row.artifactSha256 ?? '') || !/^[a-f0-9]{64}$/.test(row.notesSha256 ?? '')) {
      throw new Error(`Invalid publication receipt: ${recordVersion}`);
    }
    evidencePath(root, row.evidence);
    if (seen.has(key)) throw new Error(`Duplicate publication receipt: ${key}`);
    seen.add(key);
    const binding = `${row.sourceCommit}/${row.artifactSha256}/${row.notesSha256}`;
    if (bindings.has(recordVersion) && bindings.get(recordVersion) !== binding) throw new Error(`Version reused for different content: ${recordVersion}`);
    bindings.set(recordVersion, binding);
    const note = notes.get(recordVersion);
    if (!note) throw new Error(`Missing CHANGELOG notes for publication: ${recordVersion}`);
    if (notesSha256(note) !== row.notesSha256) throw new Error(`Published notes hash mismatch: ${recordVersion}`);
    return { row, note };
  });
  const result = { schemaVersion: 1, build: { version: id, workKey,
    ...(/^[a-f0-9]{40}$/.test(sourceCommit ?? '') ? { sourceCommit } : {}),
    ...(typeof sourceDirty === 'boolean' ? { sourceDirty } : {}) }, history: [] };
  if (releaseCandidate) {
    if (bindings.has(id)) throw new Error(`Version already published; use a new version for another release candidate: ${id}`);
    if (!notes.has(id)) throw new Error(`Release candidate requires matching CHANGELOG notes: ${id}`);
    result.currentNotice = notes.get(id);
  }
  // Source versions and platform publications are separate facts. Alpha can browse
  // backfilled CHANGELOG notes while actual publication receipts remain validated.
  const versionParts = value => value.replace(/^v/, '').split('.').map(Number);
  const compareVersions = (a, b) => {
    const left = versionParts(a), right = versionParts(b);
    for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] - right[i];
    return 0;
  };
  const publishedHere = new Map(confirmed.filter(({ row }) => row.workKey === workKey)
    .map(({ row }) => [row.version, row]));
  result.history = [...notes.values()]
    .filter(note => compareVersions(note.version, id) <= 0 && (!releaseCandidate || note.version !== id))
    // An independent contest work only displays its own confirmed history.
    .filter(note => workKey === 'alpha-test' || publishedHere.has(note.version))
    .sort((a, b) => compareVersions(b.version, a.version))
    .map(note => {
      const receipt = publishedHere.get(note.version);
      return { version: note.version, versionDate: note.notesDate,
        ...(receipt ? {
          // Actual publication dates use UTC+8 independent of the build host.
          publishedDate: new Date(Date.parse(receipt.publishedAt) + 8 * 60 * 60 * 1000).toISOString().slice(0, 10),
          sourceCommit: receipt.sourceCommit
        } : {}),
        added: note.added, improved: note.improved, fixed: note.fixed };
    });
  return result;
}
