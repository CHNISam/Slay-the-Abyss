import {portraitInventory,portraitSourceInputs} from '../scripts/official-portraits.mjs';
import {artFeatureReceipt} from '../scripts/art-features.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { buildNativeAudioGame, defaultNativeCardArt, nativeAudioBuildArgs } from '../scripts/build-native-audio-game.mjs';
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
    full = { mapPath, receiptPath, artFeatures:artFeatureReceipt(options.artFeatures), buildId: '7cf6f22e-2f12-44bb-9f01-aad514071a5f', candidate: fileRecord(mapPath), ...gitSourceIdentity(root),
      payloadDigest: payloadDigest(sourceInputs(root)),
      ...(options.artFeatures.menuBackground?{officialBackground: {templateIndex:1470123456,peakDynamicControls:13201,inputs:[{sha256:'c'.repeat(64)}]}}:{}),
      ...(options.artFeatures.selectionAvatar||options.artFeatures.battlePortrait?{officialPortraits: {...portraitInventory(options.artFeatures),imageTemplateIndex:1470123457,containerTemplateIndex:1470123458,inputs:portraitSourceInputs(options.artFeatures).map(path=>({path,sha256:'d'.repeat(64),bytes:1}))}}:{}),
      ...(options.artFeatures.cards?{readyCardArt: {enabled:true,assetCount:75,imageTemplateIndex:1470123457,containerTemplateIndex:1470123458}}:{}),
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
    const audio = { mapPath, artFeatures:full.artFeatures, sha256: fileRecord(mapPath).sha256, baseMap,
      candidate: fileRecord(mapPath), buildId: full.buildId,
      baseSha256: full.candidate.sha256, baseAfter: full.candidate.sha256,
      liveWriteEnabled: false, officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', listening: 'NOT_TESTED' };
    mutate({ audio, full, root, mapPath });
    writeFileSync(join(directory, 'candidate.json'), JSON.stringify(audio));
  };
  return { root, run: options => buildNativeAudioGame({ root, baseMap: 'base.gil', buildFull, run, ...options }), get full() { return full; }, get observed() { return observed; } };
}

test('actual audio entrypoint follows UUID full receipt and binds FINAL audio hash/version/source/notes', async t => {
  const f = fixture(t), result = await f.run({ releaseCandidate: true, workKey: 'alpha-test',artFeatures:{cards:true,menuBackground:true,selectionAvatar:true,battlePortrait:true} });
  assert.equal(f.observed.releaseCandidate, true); assert.equal(f.observed.workKey, 'alpha-test');
  assert.equal(result.receiptPath, join(f.root, 'build/native-audio-game/audio/candidate.json'));
  assert.equal(result.sha256, fileRecord(result.mapPath).sha256);
  assert.notEqual(result.sha256, f.full.candidate.sha256, 'publication copies the final audio artifact hash');
  assert.deepEqual(result.candidate, fileRecord(result.mapPath)); assert.equal(result.buildId, f.full.buildId);
  assert.deepEqual(result.release, { version: 'v0.1.1', workKey: 'alpha-test', notesSha256: 'b'.repeat(64) });
  assert.equal(result.sourceCommit, gitSourceIdentity(f.root).sourceCommit); assert.equal(result.sourceDirty, false);
  assert.deepEqual(result.sourceReceipt, fileRecord(f.full.receiptPath));
  assert.deepEqual(result.officialBackground,f.full.officialBackground,'final audio candidate retains exact runtime binding/provenance');
  assert.deepEqual(result.officialPortraits,f.full.officialPortraits,'final audio candidate retains exact portrait binding/provenance');
  assert.deepEqual(result.artFeatures,f.full.artFeatures);
  assert.deepEqual(result.readyCardArt,f.full.readyCardArt,'final audio candidate retains all75 artwork binding/provenance');
  assert.equal(JSON.parse(readFileSync(result.receiptPath)).sha256, result.sha256);
  assert.equal(result.liveWriteEnabled, false); assert.equal(result.officialImport, 'NOT_TESTED');
});
test('ordinary audio packaging does not opt into frozen notes or assert publication', async t => {
  const f = fixture(t), result = await f.run();
  assert.equal(f.observed.releaseCandidate, false);
  assert.equal('notesSha256' in result.release, false);
  assert.equal('publishedAt' in result, false); assert.equal('workId' in result, false);
  assert.equal(f.observed.nativeCardArt, undefined,'ordinary audio build must not implicitly select static card art');
  assert.notEqual(f.observed.readyCardArt,false);
});
test('normal build CLI defaults the owner-chosen custom select/card art on and preserves explicit legacy art/disable and release options', async t => {
  const ordinary = nativeAudioBuildArgs(['base.gil']);
  assert.deepEqual(ordinary.paths, ['base.gil']);
  assert.equal(ordinary.options.nativeCardArt,undefined);
  assert.notEqual(ordinary.options.readyCardArt,false);
  assert.deepEqual(ordinary.options.artFeatures,{cards:true,menuBackground:true,selectionAvatar:true,battlePortrait:false,monsters:false});
  const disabled = nativeAudioBuildArgs(['base.gil', '--native-card-art-count=0']);
  assert.deepEqual(disabled.options.nativeCardArt, { count: 0 });
  assert.equal(disabled.options.readyCardArt,false);
  const f = fixture(t); await f.run(disabled.options);
  assert.deepEqual(f.observed.nativeCardArt, { count: 0 });
  assert.equal(f.observed.readyCardArt,false);
  const noReady=nativeAudioBuildArgs(['base.gil','--no-ready-card-art']);
  assert.equal(noReady.options.readyCardArt,false);
  await f.run(noReady.options);assert.equal(f.observed.readyCardArt,false);
  for(const count of [1,5,10]) {
    const chosen=nativeAudioBuildArgs(['base.gil',`--native-card-art-registry=${defaultNativeCardArt.registry}`,`--native-card-art-count=${count}`]);
    assert.deepEqual(chosen.options.nativeCardArt,{registry:defaultNativeCardArt.registry,hosts:Array.from({length:count},(_,i)=>`battlePanel/card${i+1}`)});
  }
  const custom = nativeAudioBuildArgs(['base.gil', 'out', '--release-candidate', '--work-key=alpha-test',
    '--native-card-art-registry=custom.json', '--native-card-art-host=battlePanel/card2']);
  assert.deepEqual(custom.paths, ['base.gil', 'out']);
  assert.equal(custom.options.releaseCandidate, true);
  assert.deepEqual(custom.options.nativeCardArt, { registry: 'custom.json', hosts: ['battlePanel/card2'] });
  await assert.rejects(f.run({ nativeCardArt: custom.options.nativeCardArt }),/ENOENT/,'forwarding cannot make a nonexistent custom registry packageable');
  assert.deepEqual(f.observed.nativeCardArt, custom.options.nativeCardArt);
  for (const args of [['--native-card-art-count=10'], ['--native-card-art-registry='], ['--native-card-art-unknown=1']])
    assert.throws(() => nativeAudioBuildArgs(['base.gil', ...args]), /native art|Native art|registry/);
});
for (const [name, mutate] of [
  ['wrong full artifact', ({ audio }) => { audio.baseSha256 = '0'.repeat(64); }],
  ['changed full artifact', ({ audio }) => { audio.baseAfter = '0'.repeat(64); }],
  ['wrong final hash', ({ audio }) => { audio.sha256 = '0'.repeat(64); }],
  ['pre-audio acceptance hash', ({ audio, full }) => { audio.candidate = full.candidate; }],
  ['missing startup build marker', ({ audio }) => { delete audio.buildId; }],
  ['changed art feature config', ({audio})=>{audio.artFeatures={...audio.artFeatures,configSha256:'0'.repeat(64)};}],
  ['changed source input', ({ root }) => { writeFileSync(join(root, 'data/input.json'), '{"changed":true}'); }],
  ['new untracked source identity', ({ root }) => { writeFileSync(join(root, 'untracked.txt'), 'dirty'); }],
]) test(`audio candidate cannot inherit trusted release provenance with ${name}`, async t => {
  const f = fixture(t, mutate);
  await assert.rejects(f.run({ releaseCandidate: true }), /artifact|Source changed|provenance changed|art feature configuration/);
  const receipt = JSON.parse(readFileSync(join(f.root, 'build/native-audio-game/audio/candidate.json')));
  assert.equal('sourceReceipt' in receipt, false, 'failed packaging must not claim full-source provenance');
});
