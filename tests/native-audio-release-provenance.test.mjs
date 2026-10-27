import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { buildNativeAudioGame } from '../scripts/build-native-audio-game.mjs';
import { sourceInputs, payloadDigest } from '../scripts/build-native-candidate.mjs';
import { fileRecord } from '../scripts/evidence-files.mjs';
import { gitSourceIdentity } from '../scripts/release-notes.mjs';

function fixture(t, mutate = () => {}) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-audio-release-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'data')); writeFileSync(join(root, 'data/input.json'), '{}');
  writeFileSync(join(root, '.gitignore'), 'build/\n'); writeFileSync(join(root, 'base.gil'), 'original base');
  for (const args of [['init', '-q'], ['add', '.'], ['-c', 'user.name=Release Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture']]) {
    const git = spawnSync('git', args, { cwd: root, encoding: 'utf8' }); assert.equal(git.status, 0, git.stderr);
  }
  let full, observed;
  const buildFull = async options => {
    observed = options;
    const directory = join(options.output, '7cf6f22e-2f12-44bb-9f01-aad514071a5f');
    mkdirSync(directory, { recursive: true });
    const mapPath = join(directory, 'candidate.gil'), receiptPath = join(directory, 'candidate.json');
    writeFileSync(mapPath, 'complete game');
    full = { mapPath, receiptPath, buildId: '7cf6f22e-2f12-44bb-9f01-aad514071a5f', candidate: fileRecord(mapPath), ...gitSourceIdentity(root),
      payloadDigest: payloadDigest(sourceInputs(root)),
      release: { version: 'v0.1.1', workKey: options.workKey,
        ...(options.releaseCandidate ? { notesSha256: 'b'.repeat(64) } : {}) } };
    writeFileSync(receiptPath, JSON.stringify(full)); return full;
  };
  const run = (script, [baseMap, directory, sourceReceipt]) => {
    assert.equal(script, 'scripts/build-native-bgm-candidate.mjs');
    assert.equal(baseMap, full.mapPath, 'must consume exact returned UUID candidate, not shared stale path');
    assert.equal(sourceReceipt, full.receiptPath, 'BGM stage must preserve this exact packaged build and startup marker');
    assert.equal(existsSync(join(observed.output, 'candidate.json')), false);
    mkdirSync(directory, { recursive: true }); const mapPath = join(directory, 'audio.gil');
    writeFileSync(mapPath, 'complete game plus music');
    const audio = { mapPath, sha256: fileRecord(mapPath).sha256, baseMap,
      candidate: fileRecord(mapPath), buildId: full.buildId,
      baseSha256: full.candidate.sha256, baseAfter: full.candidate.sha256,
      liveWriteEnabled: false, officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', listening: 'NOT_TESTED' };
    mutate({ audio, full, root, mapPath });
    writeFileSync(join(directory, 'candidate.json'), JSON.stringify(audio));
  };
  return { root, run: options => buildNativeAudioGame({ root, baseMap: 'base.gil', buildFull, run, ...options }), get full() { return full; }, get observed() { return observed; } };
}

test('actual audio entrypoint follows UUID full receipt and binds FINAL audio hash/version/source/notes', async t => {
  const f = fixture(t), result = await f.run({ releaseCandidate: true, workKey: 'alpha-test' });
  assert.equal(f.observed.releaseCandidate, true); assert.equal(f.observed.workKey, 'alpha-test');
  assert.equal(result.receiptPath, join(f.root, 'build/native-audio-game/audio/candidate.json'));
  assert.equal(result.sha256, fileRecord(result.mapPath).sha256);
  assert.notEqual(result.sha256, f.full.candidate.sha256, 'publication copies the final audio artifact hash');
  assert.deepEqual(result.candidate, fileRecord(result.mapPath)); assert.equal(result.buildId, f.full.buildId);
  assert.deepEqual(result.release, { version: 'v0.1.1', workKey: 'alpha-test', notesSha256: 'b'.repeat(64) });
  assert.equal(result.sourceCommit, gitSourceIdentity(f.root).sourceCommit); assert.equal(result.sourceDirty, false);
  assert.deepEqual(result.sourceReceipt, fileRecord(f.full.receiptPath));
  assert.equal(JSON.parse(readFileSync(result.receiptPath)).sha256, result.sha256);
  assert.equal(result.liveWriteEnabled, false); assert.equal(result.officialImport, 'NOT_TESTED');
});
test('ordinary audio packaging does not opt into frozen notes or assert publication', async t => {
  const f = fixture(t), result = await f.run();
  assert.equal(f.observed.releaseCandidate, false);
  assert.equal('notesSha256' in result.release, false);
  assert.equal('publishedAt' in result, false); assert.equal('workId' in result, false);
});
for (const [name, mutate] of [
  ['wrong full artifact', ({ audio }) => { audio.baseSha256 = '0'.repeat(64); }],
  ['changed full artifact', ({ audio }) => { audio.baseAfter = '0'.repeat(64); }],
  ['wrong final hash', ({ audio }) => { audio.sha256 = '0'.repeat(64); }],
  ['pre-audio acceptance hash', ({ audio, full }) => { audio.candidate = full.candidate; }],
  ['missing startup build marker', ({ audio }) => { delete audio.buildId; }],
  ['changed source input', ({ root }) => { writeFileSync(join(root, 'data/input.json'), '{"changed":true}'); }],
  ['new untracked source identity', ({ root }) => { writeFileSync(join(root, 'untracked.txt'), 'dirty'); }],
]) test(`audio candidate cannot inherit trusted release provenance with ${name}`, async t => {
  const f = fixture(t, mutate);
  await assert.rejects(f.run({ releaseCandidate: true }), /artifact|Source changed|provenance changed/);
  const receipt = JSON.parse(readFileSync(join(f.root, 'build/native-audio-game/audio/candidate.json')));
  assert.equal('sourceReceipt' in receipt, false, 'failed packaging must not claim full-source provenance');
});
