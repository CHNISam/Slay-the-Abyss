// Production audio entrypoint: build every module before enabling native BGM.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { buildNativeCandidateFromToolchain, sourceInputs, payloadDigest } from './build-native-candidate.mjs';
import { fileRecord } from './evidence-files.mjs';
import { releaseBuildArgs, gitSourceIdentity } from './release-notes.mjs';
import { nativeCardArtArgs, verifyNativeCardArtReceipt } from './card-art-samples.mjs';

// PR356's frozen two-card candidate remains an explicit legacy opt-in. Normal
// builds leave static art unset so the full builder uses all75 dynamic assets.
export const legacyNativeCardArt = Object.freeze({
  registry: 'art/cards/traveler-geo/native-runtime-registry.json', count: 1,
});
// Preserve the old exported preset name for explicit callers, never as default.
export const defaultNativeCardArt = legacyNativeCardArt;

export function nativeAudioBuildArgs(argv) {
  const explicit = argv.some(arg => arg.startsWith('--native-card-art-'));
  const art = nativeCardArtArgs(argv);
  const parsed = releaseBuildArgs(art.args);
  return { ...parsed, options: { ...parsed.options,
    ...(explicit ? {nativeCardArt:art.nativeCardArt ?? {count:0}} : {}),
    ...(art.readyCardArt===false ? {readyCardArt:false} : {}) } };
}

function runScript(script, args, root) {
  const result = spawnSync(process.execPath, [script, ...args], { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${script} failed (${result.status})`);
}

export async function buildNativeAudioGame({ baseMap, output = 'build/native-audio-game', root = process.cwd(),
  releaseCandidate = false, workKey = 'alpha-test', nativeCardArt, readyCardArt, buildFull = buildNativeCandidateFromToolchain, run = runScript } = {}) {
  if (!baseMap) throw new Error('A base .gil is required');
  const directory = resolve(root, output);
  // The full builder owns a unique UUID workspace. Consume its returned receipt,
  // never assume a shared full/candidate.json that could be missing or stale.
  const full = await buildFull({ baseMap: resolve(root, baseMap), output: join(directory, 'full'), root, releaseCandidate, workKey, ...(readyCardArt===false?{readyCardArt:false}:{}), ...(nativeCardArt ? {nativeCardArt} : {}) });
  if (fileRecord(full.mapPath).sha256 !== full.candidate.sha256) throw new Error('Full candidate changed before audio packaging');
  verifyNativeCardArtReceipt(full.nativeCardArt,{root});
  run('scripts/build-native-bgm-candidate.mjs', [full.mapPath, join(directory, 'audio'), full.receiptPath], root);
  const receiptPath = join(directory, 'audio/candidate.json');
  const audio = JSON.parse(readFileSync(receiptPath, 'utf8'));
  if (audio.baseSha256 !== full.candidate.sha256 || audio.baseAfter !== full.candidate.sha256
    || fileRecord(audio.mapPath).sha256 !== audio.sha256 || audio.candidate?.sha256 !== audio.sha256
    || !full.buildId || audio.buildId !== full.buildId) throw new Error('Final audio artifact/build marker is not bound to the full candidate');
  if (payloadDigest(sourceInputs(root)) !== full.payloadDigest) throw new Error('Source changed during audio packaging');
  verifyNativeCardArtReceipt(full.nativeCardArt,{root});
  if (releaseCandidate) {
    const identity = gitSourceIdentity(root);
    if (identity.sourceCommit !== full.sourceCommit || identity.sourceDirty || full.sourceDirty !== false
      || !full.release?.notesSha256) throw new Error('Release candidate provenance changed during audio packaging');
  }
  Object.assign(audio, { sourceCommit: full.sourceCommit, sourceDirty: full.sourceDirty, payloadDigest: full.payloadDigest,
    startedAt: full.startedAt, productionManifest: full.productionManifest,
    sourceReceipt: fileRecord(full.receiptPath), ...(full.release ? { release: full.release } : {}),
    ...(full.nativeCardArt ? { nativeCardArt: full.nativeCardArt } : {}),
    ...(full.officialPortraits ? {officialPortraits:full.officialPortraits} : {}),
    ...(full.readyCardArt ? {readyCardArt:full.readyCardArt} : {}),
    ...(full.officialBackground ? { officialBackground: full.officialBackground } : {}) });
  writeFileSync(receiptPath, JSON.stringify(audio, null, 2) + '\n');
  return { ...audio, receiptPath };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { paths, options } = nativeAudioBuildArgs(process.argv.slice(2));
    if (!paths[0] || paths.length > 2) throw new Error('Usage: npm run build:native -- <base.gil> [new-output-directory] [--release-candidate] [--work-key=alpha-test] [--no-ready-card-art | --native-card-art-count=0 | --native-card-art-registry=<file> --native-card-art-count=1|5|10 | --native-card-art-host=<host>]');
    const receipt = await buildNativeAudioGame({ baseMap: paths[0], output: paths[1], ...options });
    console.log(`Complete game with native music: ${receipt.receiptPath}`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
