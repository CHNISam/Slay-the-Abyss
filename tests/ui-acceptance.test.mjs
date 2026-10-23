import test from 'node:test';
import assert from 'node:assert/strict';
import { criticalUiChecks, reviewUiAcceptance } from '../scripts/verify-ui-acceptance.mjs';

test('UI signoff requires real reviewed evidence for the exact candidate and every critical field', () => {
  const hash = 'fixture-candidate';
  const manifest = {screens:Object.fromEntries(Object.entries(criticalUiChecks).map(([name, fields]) => [name, {
    status:'pass',candidateHash:hash,baseline:'approved',screenshot:'actual-game',reviewer:'fixture',reviewedAt:'fixture',
    checks:Object.fromEntries(fields.map(field => [field,true])),
  }]))};
  const knownFiles = path => ['approved','actual-game'].includes(path);
  assert.deepEqual(reviewUiAcceptance(manifest,hash,knownFiles),[]);
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
