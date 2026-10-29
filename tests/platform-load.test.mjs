import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, mkdtempSync, writeFileSync, rmSync, mkdirSync } from 'node:fs';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { spawnSync } from 'node:child_process';
import { verifyPlatformRelease, loadChecks, growthWarnings } from '../scripts/platform-load.mjs';
import { checkArchitecture } from '../scripts/check-architecture.mjs';
import { candidateScriptFiles, excludedProductionModules } from '../scripts/native-candidate-scripts.mjs';
import { sourceInputs, payloadDigest } from '../scripts/build-native-candidate.mjs';

const raw = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), Buffer.from('synthetic test evidence')]);
const artifact = {path: 'report.txt', sha256: createHash('sha256').update(raw).digest('hex')};
const measuredAt = '2026-10-30T01:00:00Z';
const now = Date.parse('2026-10-30T02:00:00Z');
const receipt = {sourceCommit: 'a'.repeat(40), sourceDirty: false, buildId: '12345678-1234-1234-1234-123456789abc',
  payloadDigest: 'b'.repeat(64), candidate: {sha256: 'c'.repeat(64)}, startedAt: '2026-10-30T00:00:00Z',
  release: {notesSha256: 'd'.repeat(64)}};
function fixture() {
  const reading = limitMB => ({source: 'official-editor', unit: 'MB', limitMB, valueMB: 0.01, measuredAt, artifacts: [artifact]});
  return {schemaVersion: 1, sourceCommit: receipt.sourceCommit, buildId: receipt.buildId,
    payloadDigest: receipt.payloadDigest, candidateSha256: receipt.candidate.sha256,
    recordedAt: measuredAt, reviewer: 'fixture reviewer', clientVersion: '7.1.0', uidRedacted: true,
    loadTierUnchanged: true, dynamicDetectionEnabled: true, detectorOverheadAcknowledged: true,
    levelStorage: {...reading(20), valueMB: 8.96}, serverStorage: reading(3),
    rawDynamicReport: {source: 'official-sandbox', artifacts: [artifact]},
    screenshots: {artifacts: [artifact]},
    checks: Object.fromEntries(loadChecks.map(name => [name, {status: 'PASS', measuredAt, notes: 'fixture reviewed', unresolved: [], artifacts: [artifact]}]))};
}
const verify = (evidence, candidate = receipt, read = () => raw) => verifyPlatformRelease(candidate, evidence, read, now);

test('official evidence is mandatory and a complete matching synthetic fixture passes', () => {
  assert.equal(verify().status, 'UNVERIFIED');
  assert.equal(verify(fixture()).status, 'PASS');
});
test('20MB and 3MB are independent hard limits; 16MB is only a warning', () => {
  for (const [field, limit] of [['levelStorage', 20], ['serverStorage', 3]]) {
    const e = fixture(); e[field].valueMB = limit;
    assert.equal(verify(e).status, 'PASS');
    e[field].valueMB = limit + 0.01;
    assert.equal(verify(e).status, 'BLOCKED');
    for (const value of [-1, NaN, Infinity, '0.01']) { e[field].valueMB = value; assert.equal(verify(e).status, 'BLOCKED'); }
  }
  const e = fixture(); e.levelStorage.valueMB = 16.01;
  assert.equal(verify(e).warnings.length, 1);
  e.levelStorage.source = 'gil-file-size'; assert.equal(verify(e).status, 'BLOCKED');
});
test('each official load and mobile check is required, unresolved anomalies cannot pass', () => {
  for (const key of loadChecks) {
    const e = fixture(); delete e.checks[key]; assert.equal(verify(e).status, 'BLOCKED', key);
    e.checks[key] = {status: 'PASS', measuredAt, notes: 'reviewed', unresolved: ['overload'], artifacts: [artifact]};
    assert.equal(verify(e).status, 'BLOCKED', key);
  }
});
test('rejects another candidate, old times, altered evidence, dirty source and missing detector report', () => {
  for (const field of ['sourceCommit', 'buildId', 'payloadDigest', 'candidateSha256']) {
    const e = fixture(); e[field] = 'other'; assert.equal(verify(e).status, 'BLOCKED');
  }
  for (const field of ['loadTierUnchanged', 'uidRedacted', 'dynamicDetectionEnabled', 'detectorOverheadAcknowledged']) {
    const e = fixture(); e[field] = false; assert.equal(verify(e).status, 'BLOCKED');
  }
  for (const date of ['2026-10-29', '2030-01-01', 'bad date', '2026-10-30T01:00:00']) {
    const e = fixture(); e.levelStorage.measuredAt = date; assert.equal(verify(e).status, 'BLOCKED');
  }
  assert.equal(verify(fixture(), {...receipt, sourceDirty: true}).status, 'BLOCKED');
  assert.equal(verify(fixture(), {...receipt, release: undefined}).status, 'BLOCKED');
  assert.equal(verify(fixture(), receipt, () => Buffer.from('altered')).status, 'BLOCKED');
  const e = fixture(); delete e.rawDynamicReport; assert.equal(verify(e).status, 'BLOCKED');
});
test('production exclusion has no imports, and growth is reported without treating source bytes as platform MB', () => {
  const a = checkArchitecture(); assert.deepEqual(a.errors, []);
  assert(!a.edges.some(edge => excludedProductionModules.includes(edge.to)));
  const scripts = candidateScriptFiles();
  assert(!scripts.some(row => row.name === 'abyss_random'));
  assert(readFileSync('src/lua/abyss_random.lua').length > 0, 'development source is preserved');
  assert.equal(growthWarnings({luaBytes: 111}, {luaBytes: 100}).length, 1);
});

test('release CLI rejects missing evidence, changed candidate, current payload drift and broken art provenance', () => {
  mkdirSync('build', {recursive: true});
  const directory = mkdtempSync(resolve('build/platform-load-fixture-'));
  try {
    const path = join(directory, 'candidate.gil'), receiptPath = join(directory, 'candidate.json');
    writeFileSync(path, raw);
    const current = {...receipt, payloadDigest: payloadDigest(sourceInputs(process.cwd())),
      candidate: {path, sha256: createHash('sha256').update(raw).digest('hex')}};
    const run = value => {
      writeFileSync(receiptPath, JSON.stringify(value));
      return spawnSync(process.execPath, ['scripts/platform-load.mjs', 'release', receiptPath], {encoding: 'utf8', timeout: 15000});
    };
    let result = run(current);
    assert.equal(result.status, 1); assert.match(result.stdout, /UNVERIFIED/);
    result = run({...current, candidate: {...current.candidate, sha256: 'f'.repeat(64)}});
    assert.equal(result.status, 1); assert.match(result.stderr, /Candidate file changed/);
    result = run({...current, payloadDigest: 'f'.repeat(64)});
    assert.equal(result.status, 1); assert.match(result.stderr, /payload differs/);
    result = run({...current, nativeCardArt: {inputs: [], outputs: []}});
    assert.equal(result.status, 1); assert.match(result.stderr, /native art candidate provenance/);
    assert.equal(JSON.parse(readFileSync('build/platform-load-release.json')).status, 'BLOCKED', 'cannot leave stale PASS after a failure');
  } finally {
    const rel = relative(resolve('build'), directory);
    assert(!isAbsolute(rel) && !rel.startsWith('..') && rel.startsWith('platform-load-fixture-'));
    rmSync(directory, {recursive: true, force: true});
  }
});
