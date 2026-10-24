import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { criticalUiChecks, reviewUiAcceptance } from '../scripts/verify-ui-acceptance.mjs';

test('UI signoff requires real reviewed evidence for the exact candidate and every critical field', () => {
  const hash = 'fixture-candidate';
  const manifest = {screens:Object.fromEntries(Object.entries(criticalUiChecks).map(([name, fields]) => [name, {
    status:'pass',candidateHash:hash,baseline:'approved',screenshot:'actual-game',reviewer:'fixture',reviewedAt:'fixture',
    checks:Object.fromEntries(fields.map(field => [field,true])),
  }]))};
  const knownFiles = path => ['approved','actual-game'].includes(path);
  assert.deepEqual(reviewUiAcceptance(manifest,hash,knownFiles),[]);
  for (const field of ['gold', 'hpAndMaxHp']) {
    const missingResource = structuredClone(manifest);
    delete missingResource.screens.map.checks[field];
    assert(reviewUiAcceptance(missingResource,hash,knownFiles).includes(`map: ${field} not verified in game`));
  }
  const missingHp = structuredClone(manifest); delete missingHp.screens.battle.checks.actorHpAndMaxHp;
  assert(reviewUiAcceptance(missingHp,hash,knownFiles).some(error => error.includes('actorHpAndMaxHp')));
  const mockOnly = structuredClone(manifest); delete mockOnly.screens.shop.screenshot;
  assert(reviewUiAcceptance(mockOnly,hash,knownFiles).some(error => error.includes('screenshot missing')));
  assert(reviewUiAcceptance(manifest,'new-build',knownFiles).some(error => error.includes('another candidate')));
  const noReview = structuredClone(manifest); delete noReview.screens.battle.reviewer;
  assert(reviewUiAcceptance(noReview,hash,knownFiles).some(error => error.includes('not been reviewed')));
  const deferred = structuredClone(manifest); deferred.screens.result.status='missing';
  assert(reviewUiAcceptance(deferred,hash,knownFiles).includes('result: missing'));
});

// All artifacts below are synthetic validator fixtures, never game evidence.
// The contract is necessary, not sufficient: an actual screenshot cannot be a
// directory or an empty file. Passing these tests does not grant UI acceptance.
const fixtureRoot = fileURLToPath(new URL('../', import.meta.url));
function withSyntheticEvidence(run) {
  const dir = mkdtempSync(join(fixtureRoot, '.ui-evidence-fixture-'));
  try {
    const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z/D/PwAG/gL+DHWJ3gAAAABJRU5ErkJggg==', 'base64');
    const baseline = join(dir, 'synthetic-baseline.png');
    const screenshot = join(dir, 'synthetic-screenshot.png');
    writeFileSync(baseline, image);
    writeFileSync(screenshot, image);
    const candidate = join(dir, 'synthetic-candidate.gil');
    const candidateBytes = 'SYNTHETIC VALIDATOR FIXTURE: not a game save or acceptance proof';
    writeFileSync(candidate, candidateBytes);
    const hash = createHash('sha256').update(candidateBytes).digest('hex');
    const manifest = { screens: Object.fromEntries(Object.entries(criticalUiChecks).map(([name, fields]) => [name, {
      status: 'pass', candidateHash: hash, baseline, screenshot,
      reviewer: 'SYNTHETIC TEST ONLY', reviewedAt: '2026-10-23T12:00:00Z',
      checks: Object.fromEntries(fields.map(field => [field, true])),
    }])) };
    const missing = join(dir, 'not-created.png');
    const directory = join(dir, 'not-an-image.png');
    mkdirSync(directory);
    const empty = join(dir, 'empty.png');
    writeFileSync(empty, '');
    run({ dir, manifest, hash, candidate, missing, directory, empty });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('synthetic evidence control rejects an absent screenshot without injected filesystem callbacks', () => {
  withSyntheticEvidence(({ manifest, hash, missing }) => {
    assert.deepEqual(reviewUiAcceptance(manifest, hash), []);
    manifest.screens.battle.screenshot = missing;
    assert(reviewUiAcceptance(manifest, hash).some(error => error.startsWith('battle:') && error.includes('screenshot')));
  });
});

for (const field of ['baseline', 'screenshot']) {
  for (const kind of ['directory', 'empty']) {
    test(`UI evidence must reject ${kind} ${field} artifacts`, () => {
      withSyntheticEvidence(fixture => {
        fixture.manifest.screens.battle[field] = fixture[kind];
        assert(reviewUiAcceptance(fixture.manifest, fixture.hash).some(error => error.startsWith('battle:') && error.includes(field)),
          `A ${kind} is not a reviewable ${field}; this fixture must not receive an empty error list`);
      });
    });
  }
}

test('CLI must fail when the exact-hash review has only a directory instead of a screenshot', () => {
  withSyntheticEvidence(({ dir, manifest, candidate, directory }) => {
    manifest.screens.battle.screenshot = directory;
    const reviewFile = join(dir, 'synthetic-review.json');
    writeFileSync(reviewFile, JSON.stringify(manifest));
    const result = spawnSync(process.execPath, [join(fixtureRoot, 'scripts/verify-ui-acceptance.mjs'), reviewFile, candidate], {
      cwd: fixtureRoot, encoding: 'utf8',
    });
    assert.equal(result.status, 1, `Non-image evidence must block acceptance; actual stdout: ${result.stdout}`);
    assert.match(result.stderr, /battle:.*screenshot/);
  });
});

test('UI evidence rejects broken screenshot links when symbolic links are supported', t => {
  withSyntheticEvidence(({ dir, manifest, hash, missing }) => {
    const link = join(dir, 'broken-screenshot.png');
    try { symlinkSync(missing, link); }
    catch (error) {
      if (['EPERM', 'EACCES', 'ENOTSUP'].includes(error.code)) return t.skip('Symbolic links are not permitted in this environment');
      throw error;
    }
    manifest.screens.battle.screenshot = link;
    assert(reviewUiAcceptance(manifest, hash).some(error => error.startsWith('battle:') && error.includes('screenshot')));
  });
});

test('UI evidence rejects unreadable screenshot files when file permissions are enforced', t => {
  withSyntheticEvidence(({ manifest, hash }) => {
    const screenshot = manifest.screens.battle.screenshot;
    chmodSync(screenshot, 0);
    try {
      try {
        readFileSync(screenshot);
        return t.skip('This environment can read files despite mode 000');
      } catch (error) {
        if (!['EACCES', 'EPERM'].includes(error.code)) throw error;
      }
      assert(reviewUiAcceptance(manifest, hash).some(error => error.startsWith('battle:') && error.includes('screenshot')));
    } finally { chmodSync(screenshot, 0o600); }
  });
});
