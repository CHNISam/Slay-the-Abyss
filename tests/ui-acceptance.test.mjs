import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { sha256 } from '../scripts/evidence-files.mjs';
import { approvedDesignDigest, criticalUiChecks, reviewUiAcceptance } from '../scripts/verify-ui-acceptance.mjs';

test('UI proof accepts complete decoded fixture and rejects missing fields, changed images and invalid reviews',()=>{
  const dir=mkdtempSync(join(tmpdir(),'abyss-ui-proof-'));
  try {
    const image=join(dir,'actual.png');
    const result=spawnSync(process.env.ABYSS_PYTHON||'python',['-c','from PIL import Image; import sys; Image.new("RGB",(2,2)).save(sys.argv[1])',image],{encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    const hash='a'.repeat(64),imageHash=sha256(readFileSync(image));
    const expected={candidateHash:hash,buildId:'fixture',runId:'fixture-run',payloadDigest:'b'.repeat(64),baselineRevision:'c'.repeat(64)};
    const manifest={schemaVersion:1,buildId:expected.buildId,runId:expected.runId,payloadDigest:expected.payloadDigest,baselineRevision:expected.baselineRevision,
      screens:Object.fromEntries(Object.entries(criticalUiChecks).map(([screen,fields])=>[screen,{
        status:'pass',candidateHash:hash,buildId:'fixture',runId:'fixture-run',baseline:'actual.png',baselineHash:imageHash,
        screenshot:'actual.png',screenshotHash:imageHash,reviewer:'fixture only',reviewedAt:'2026-10-01T00:00:00Z',
        reviewScope:'validator fixture, not real game acceptance',operations:['fixture click'],unresolved:[],sharedScreenshotReason:'synthetic shared fixture for validator only',
        checks:Object.fromEntries(fields.map(field=>[field,true])),
      }]))};
    const options={evidenceRoot:dir,baselineRoot:dir},check=m=>reviewUiAcceptance(m,expected,options);
    assert.deepEqual(check(manifest),[]);
    for(const [field,value,match] of [['reviewedAt','bad date',/reviewed/],['reviewedAt','2026-02-31T00:00:00Z',/reviewed/],['reviewer','',/reviewed/],['screenshot','missing.png',/screenshot/],['screenshotHash','f'.repeat(64),/hash mismatch/],['runId','other',/another build/]]) {
      const bad=structuredClone(manifest);bad.screens.battle[field]=value;assert(check(bad).some(e=>match.test(e)),field);
    }
    for (const screen of ['character','potions','exit']) {
      assert.ok(criticalUiChecks[screen]?.length, screen);
      const absent = structuredClone(manifest); delete absent.screens[screen];
      assert(check(absent).some(error => error.startsWith(`${screen}:`)), screen);
      for (const field of criticalUiChecks[screen]) {
        const incomplete = structuredClone(manifest); delete incomplete.screens[screen].checks[field];
        assert(check(incomplete).some(error => error.includes(`${screen}: ${field} not verified in game`)), `${screen}/${field}`);
      }
    }
    const missing=structuredClone(manifest);delete missing.screens.battle.checks.actorHpAndMaxHp;
    assert(check(missing).some(e=>e.includes('actorHpAndMaxHp')));
    for(const field of ['gold','hpAndMaxHp']) {
      assert(criticalUiChecks.map.includes(field));
      const absent=structuredClone(manifest);delete absent.screens.map.checks[field];
      assert(check(absent).some(e=>e.includes(field)));
    }
    mkdirSync(join(dir,'directory.png'));writeFileSync(join(dir,'empty.png'),'');
    for(const screenshot of ['directory.png','empty.png']) {
      const invalid=structuredClone(manifest);invalid.screens.battle.screenshot=screenshot;
      assert(check(invalid).some(e=>e.includes('screenshot missing or invalid')));
    }
    const shared=structuredClone(manifest);delete shared.screens.battle.sharedScreenshotReason;
    assert(check(shared).some(e=>e.includes('shared screenshot')));
    writeFileSync(image,'fake png');
    for(const row of Object.values(manifest.screens))row.baselineHash=row.screenshotHash=sha256(readFileSync(image));
    assert(check(manifest).some(error=>error.includes('Image decode failed')));
  }finally{rmSync(dir,{recursive:true,force:true});}
});


test('approved baseline binds active canvas bytes while leaving retired PatchNotes historical', () => {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-current-ui-baseline-'));
  try {
    for (const name of ['prototype', 'screens', 'ui-canvas']) mkdirSync(join(dir, name));
    writeFileSync(join(dir, 'UI_DESIGN.md'), 'PR19');
    writeFileSync(join(dir, 'ui-canvas', 'Main.dc.html'), 'approved battle');
    writeFileSync(join(dir, 'ui-canvas', 'PatchNotes.dc.html'), 'retired');
    const before = approvedDesignDigest(dir);
    writeFileSync(join(dir, 'ui-canvas', 'PatchNotes.dc.html'), 'historical edits do not restore it');
    assert.equal(approvedDesignDigest(dir), before);
    writeFileSync(join(dir, 'ui-canvas', 'Main.dc.html'), 'different battle');
    assert.notEqual(approvedDesignDigest(dir), before);
    for (const checks of Object.values(criticalUiChecks)) {
      for (const check of ['native1280x720', 'pcSafeArea', 'mobileSafeArea', 'fontAndLayers', 'input', 'capacityAndPerformance']) assert.ok(checks.includes(check));
    }
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
