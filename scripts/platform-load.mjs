import {monsterActorInventory,monsterActorTemplateName} from './monster-art.mjs';
import {artBuildOptionsFromReceipt,readArtFeatures} from './art-features.mjs';
import {portraitRuntimeInventory} from './official-portraits.mjs';
import {readyArtRuntimeInventory} from './art/ready-card-runtime.mjs';
import {backgroundRuntimeInventory} from './official-background.mjs';
import { readFileSync, mkdirSync, writeFileSync, realpathSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import { candidateScriptFiles, excludedProductionModules } from './native-candidate-scripts.mjs';
import { checkArchitecture } from './check-architecture.mjs';
import { assertNativeUiCapacity } from './build-ui.mjs';
import { sourceInputs, payloadDigest } from './build-native-candidate.mjs';
import { verifyNativeCardArtReceipt } from './card-art-samples.mjs';
import { validDate } from './evidence-files.mjs';
import { gitSourceIdentity } from './release-notes.mjs';
import {assertCandidateArtReceipt} from './candidate-art-policy.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function packageInventory(directory = 'build/lua') {
  const artFeatures=readArtFeatures(directory);
  const architecture = checkArchitecture();
  if (architecture.errors.length) throw Error('Production dependency analysis failed; run check:architecture');
  for (const edge of architecture.edges) if (excludedProductionModules.includes(edge.to))
    throw Error(`Excluded production dependency: ${edge.from} -> ${edge.to}`);
  const modules = candidateScriptFiles('src/lua', directory).map(({name, sourceFile}) => {
    const bytes = readFileSync(sourceFile);
    return { name, bytes: bytes.length, sha256: hash(bytes) };
  });
  const reachable = new Set();
  function dependency(name) {
    if (reachable.has(name)) return;
    reachable.add(name);
    for (const edge of architecture.edges) if (edge.from === name) dependency(edge.to);
  }
  dependency('abyss_ui');
  const unreachable = modules.filter(row => !reachable.has(row.name));
  if (unreachable.length) throw Error(`Unreferenced production modules: ${unreachable.map(row => row.name).join(', ')}`);
  const digests = new Set();
  for (const module of modules) {
    if (digests.has(module.sha256)) throw Error(`Duplicate mapped Lua payload: ${module.name}`);
    digests.add(module.sha256);
  }
  const layout = JSON.parse(readFileSync(join(directory, 'game-ui.json')));
  const templates = JSON.parse(readFileSync(join(directory, 'game-ui-templates.json')));
  const templateNames = new Set(), templateDigests = new Set();
  let controls = 0, hiddenControls = 0, artPools = 0, maxChildren = 0;
  const primitives = new Map();
  function visit(nodes, hidden = false) {
    const names = new Set();
    maxChildren = Math.max(maxChildren, nodes.length);
    for (const node of nodes) {
      if (names.has(node.name)) throw Error(`Duplicate sibling control: ${node.name}`);
      names.add(node.name); controls++;
      const invisible = hidden || node.visible === false;
      if (invisible) hiddenControls++;
      if (node.name === 'artSamples') artPools++;
      if (!node.children?.length) {
        const {name, ...shape} = node;
        const key = hash(JSON.stringify(shape));
        primitives.set(key, (primitives.get(key) ?? 0) + 1);
      }
      visit(node.children ?? [], invisible);
    }
  }
  for (const tree of [layout, ...templates]) {
    assertNativeUiCapacity(tree);
    visit(tree === layout ? layout.controls : [tree]);
  }
  for (const template of templates) {
    const {name, ...body} = template, digest = hash(JSON.stringify(body));
    if (templateNames.has(name) || templateDigests.has(digest)) throw Error(`Duplicate UI template: ${name}`);
    templateNames.add(name); templateDigests.add(digest);
  }
  return {schemaVersion: 1, ...gitSourceIdentity(process.cwd()), measurement: 'offline-production-inputs-not-official-storage', modules,
    luaBytes: modules.reduce((n, row) => n + row.bytes, 0),
    layoutJsonBytes: Buffer.byteLength(JSON.stringify(layout)), templateJsonBytes: Buffer.byteLength(JSON.stringify(templates)),
    controls, hiddenControls, templates: templates.length, artPools, maxChildren,
    monsterActors: {...monsterActorInventory(templates.find(t=>t.name===monsterActorTemplateName)),
      runtimeControlsFormula: "controlsPerActor * drawableActors + controlsPerPower * (displayedPowers + liveIntentParticles) + actorPowerAndIntentPagingContainers", peakDrawableActors: null,
      peakStatus: "unverified-not-a-static-visibility-cap"},
    repeatedPrimitiveInstances: [...primitives.values()].reduce((n, count) => n + Math.max(0, count - 1), 0),
    artFeatures,
    runtimeCardArt: artFeatures.cards ? readyArtRuntimeInventory(directory) : undefined,
    runtimePortraits: portraitRuntimeInventory(directory),
    runtimeBackgrounds: [backgroundRuntimeInventory(directory)].filter(Boolean),
    excludedModules: excludedProductionModules};
}

export function growthWarnings(report, baseline) {
  return ['luaBytes', 'layoutJsonBytes', 'templateJsonBytes', 'controls', 'hiddenControls', 'artPools']
    .filter(key => report[key] > baseline[key] * 1.1)
    .map(key => `${key}: ${baseline[key]} -> ${report[key]} (over 10% growth; review assembly, not official MB)`);
}

export const loadChecks = ['staticGlobal', 'staticRegions', 'clientCompute', 'clientMemory', 'serverProcessor',
  'serverMemory', 'combatPeak', 'complexHand', 'enemyEffectsConcurrency', 'sceneTransitions', 'repeatedEntryExit',
  'officialUpload', 'launchAndOperate', 'mobilePerformance', 'mobileInteraction'];

export function verifyPlatformRelease(receipt, evidence, readArtifact, now = Date.now()) {
  const errors = [], warnings = [];
  const fail = text => errors.push(text);
  const identity = {sourceCommit: receipt.sourceCommit, buildId: receipt.buildId,
    candidateSha256: receipt.candidate?.sha256, payloadDigest: receipt.payloadDigest};
  if (receipt.sourceDirty !== false || !/^[a-f0-9]{40}$/.test(identity.sourceCommit ?? '')
    || !/^[a-f0-9-]{36}$/.test(identity.buildId ?? '')
    || !['candidateSha256', 'payloadDigest'].every(k => /^[a-f0-9]{64}$/.test(identity[k] ?? '')))
    fail('Clean candidate identity required');
  if (!/^[a-f0-9]{64}$/.test(receipt.release?.notesSha256 ?? '')) fail('Frozen RC release provenance required');
  if (!evidence) return {status: 'UNVERIFIED', identity, errors: [...errors, 'Official load evidence missing'], warnings};
  for (const [key, value] of Object.entries(identity)) if (evidence[key] !== value) fail(`Candidate mismatch: ${key}`);
  if (evidence.schemaVersion !== 1 || !evidence.clientVersion?.trim() || !evidence.reviewer?.trim()
    || evidence.uidRedacted !== true || evidence.loadTierUnchanged !== true) fail('Missing review/client/redaction/load-tier attestation');
  const started = Date.parse(receipt.startedAt);
  function time(value) {
    const parsed = Date.parse(value);
    return validDate(value) && validDate(receipt.startedAt) && Number.isFinite(started) && parsed >= started && parsed <= now
      && parsed <= Date.parse(evidence.recordedAt);
  }
  if (!time(evidence.recordedAt)) fail('Invalid evidence time');
  function artifacts(row, name) {
    if (!Array.isArray(row?.artifacts) || !row.artifacts.length) { fail(`${name}: raw evidence missing`); return; }
    for (const artifact of row.artifacts) {
      try {
        const bytes = readArtifact(artifact.path);
        if (!bytes.length || !/^[a-f0-9]{64}$/.test(artifact.sha256 ?? '') || hash(bytes) !== artifact.sha256)
          fail(`${name}: evidence hash mismatch`);
      } catch { fail(`${name}: unreadable evidence`); }
    }
  }
  for (const [name, limit] of [['levelStorage', 20], ['serverStorage', 3]]) {
    const row = evidence[name];
    if (row?.source !== 'official-editor' || row.unit !== 'MB' || row.limitMB !== limit
      || !Number.isFinite(row.valueMB) || row.valueMB < 0 || row.valueMB > limit || !time(row.measuredAt))
      fail(`${name}: official storage reading required within ${limit}MB`);
    if (name === 'levelStorage' && row?.valueMB > 16) warnings.push('Official level storage exceeds internal 16MB budget');
    artifacts(row, name);
  }
  for (const name of loadChecks) {
    const row = evidence.checks?.[name];
    if (row?.status !== 'PASS' || !time(row.measuredAt) || !row.notes?.trim()
      || !Array.isArray(row.unresolved) || row.unresolved.length) fail(`${name}: missing or unresolved official acceptance`);
    artifacts(row, name);
  }
  if (evidence.dynamicDetectionEnabled !== true || evidence.detectorOverheadAcknowledged !== true
    || evidence.rawDynamicReport?.source !== 'official-sandbox') fail('Official dynamic report/detector attestation missing');
  artifacts(evidence.rawDynamicReport, 'rawDynamicReport');
  artifacts(evidence.screenshots, 'screenshots');
  for (const artifact of evidence.screenshots?.artifacts ?? []) {
    try {
      const bytes = readArtifact(artifact.path);
      const png = bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
      const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      if (!png && !jpeg) fail('screenshots: PNG/JPEG required');
    } catch { fail('screenshots: unreadable image'); }
  }
  return {status: errors.length ? 'BLOCKED' : 'PASS', identity, clientVersion: evidence.clientVersion,
    recordedAt: evidence.recordedAt, verifiedAt: new Date(now).toISOString(), errors, warnings};
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [mode, directory = 'build/lua', evidencePath] = process.argv.slice(2);
    let report;
    if (mode === 'daily') {
      report = packageInventory(directory);
      const baseline = JSON.parse(readFileSync('config/platform-load-baseline.json'));
      const observation = baseline.officialObservation;
      if (!Number.isFinite(observation?.levelStorageMB) || observation.levelStorageMB > 20
        || observation.levelStorageMB < 0 || !Number.isFinite(observation?.serverStorageMB)
        || observation.serverStorageMB < 0 || observation.serverStorageMB > 3)
        throw Error('Recorded official storage exceeds a hard limit or is malformed');
      report.warnings = growthWarnings(report, baseline);
      if (observation.levelStorageMB > 16) report.warnings.push('Recorded official level storage exceeds 16MB internal budget; historical reading does not verify this candidate');
      report.baselineSourceCommit = baseline.sourceCommit;
      report.delta = Object.fromEntries(['luaBytes', 'layoutJsonBytes', 'templateJsonBytes', 'controls', 'hiddenControls']
        .map(key => [key, report[key] - baseline[key]]));
    } else if (mode === 'release') {
      const receipt = JSON.parse(readFileSync(directory));
      if (hash(readFileSync(receipt.candidate.path)) !== receipt.candidate.sha256) throw Error('Candidate file changed');
      verifyNativeCardArtReceipt(receipt.nativeCardArt, {root: process.cwd()});
      assertCandidateArtReceipt(receipt);
      const artOptions=artBuildOptionsFromReceipt(receipt);
      if (payloadDigest(sourceInputs(process.cwd(),artOptions)) !== receipt.payloadDigest) throw Error('Candidate payload differs from current production inputs');
      verifyNativeCardArtReceipt(receipt.nativeCardArt, {root: process.cwd()});
      const evidence = evidencePath ? JSON.parse(readFileSync(evidencePath)) : undefined;
      // Artifact paths are relative to the evidence file, never fetched from a URL.
      const {dirname, relative, isAbsolute} = await import('node:path');
      const root = evidencePath && realpathSync(dirname(resolve(evidencePath)));
      report = verifyPlatformRelease(receipt, evidence, path => {
        if (typeof path !== 'string' || isAbsolute(path)) throw Error('Relative evidence path required');
        const target = realpathSync(resolve(root, path)), rel = relative(root, target);
        if (rel.startsWith('..') || isAbsolute(rel)) throw Error('Evidence escapes directory');
        return readFileSync(target);
      });
      if (report.status !== 'PASS') process.exitCode = 1;
    } else throw Error('Usage: platform-load.mjs daily [generated-directory] | release <candidate.json> [official-evidence.json]');
    mkdirSync('build', {recursive: true});
    writeFileSync(`build/platform-load-${mode}.json`, JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({...report, ...(report.modules ? {modules: report.modules.length} : {})}, null, 2));
  } catch (error) {
    // Never leave an earlier PASS on disk after a failed candidate verification.
    mkdirSync('build', {recursive: true});
    const mode = process.argv[2] === 'release' ? 'release' : 'daily';
    writeFileSync(`build/platform-load-${mode}.json`, JSON.stringify({status: 'BLOCKED',
      verifiedAt: new Date().toISOString(), errors: [error.message]}, null, 2) + '\n');
    console.error(`BLOCKED: ${error.message}`); process.exitCode = 1;
  }
}
