import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { requireStartupEvidence } from '../scripts/native-playtest-evidence.mjs';
import { criticalUiChecks, reviewUiAcceptance } from '../scripts/verify-ui-acceptance.mjs';

test('F3: empty raw log cannot be replaced by independently supplied ready prints', () => {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-f3-'));
  try {
    const file = join(dir, 'log.gia'); writeFileSync(file, '');
    const status = { state:'succeeded', runId:'wrong-run', runDir:dir,
      steps:[{step:'log-subscribed',clientScripts:true}],
      log:{file,prints:[{clientScript:true,text:'ABYSS_UI ready'}]} };
    assert.throws(() => requireStartupEvidence(status, {startedAt:0,runId:'expected-run',candidateHash:'a'.repeat(64),buildId:'current'}));
  } finally { rmSync(dir,{recursive:true,force:true}); }
});

test('F4: directories, text PNGs and invalid review dates cannot sign off UI', () => {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-f4-'));
  try {
    const baseline = join(dir, 'baseline'); mkdirSync(baseline);
    const screenshot = join(dir, 'fake.png'); writeFileSync(screenshot, 'not an image');
    const hash = 'a'.repeat(64);
    const manifest = {screens:Object.fromEntries(Object.entries(criticalUiChecks).map(([screen, fields]) => [screen, {
      status:'pass',candidateHash:hash,baseline,screenshot,reviewer:'fixture',reviewedAt:'not-a-date',
      checks:Object.fromEntries(fields.map(field => [field,true])),
    }]))};
    assert(reviewUiAcceptance(manifest,hash).length > 0);
  } finally { rmSync(dir,{recursive:true,force:true}); }
});
