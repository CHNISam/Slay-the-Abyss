import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { requireStartupEvidence } from '../scripts/native-playtest-evidence.mjs';

test('startup acceptance rejects lost subscription, absent/stale/foreign logs and runtime faults', () => {
  const runDir = mkdtempSync(join(tmpdir(), 'abyss-run-evidence-'));
  const logFile = join(runDir, 'session-log.gia');
  writeFileSync(logFile, 'fixture');
  const status = {state:'succeeded',runDir,steps:[{step:'log-subscribed',clientScripts:true}],
    log:{file:logFile,prints:[{clientScript:true,text:'ABYSS_UI ready'}]}};
  try {
    assert.equal(requireStartupEvidence(status, 0), true);
    assert.throws(() => requireStartupEvidence({...status,steps:[]},0), /subscription/);
    assert.throws(() => requireStartupEvidence({...status,log:{file:null}},0), /No run-specific/);
    assert.throws(() => requireStartupEvidence(status, Date.now()+10000), /Stale/);
    assert.throws(() => requireStartupEvidence({...status,runDir:join(runDir,'different-run')},0), /another run/);
    assert.throws(() => requireStartupEvidence({...status,log:{...status.log,prints:[]}},0), /never reached ready/);
    assert.throws(() => requireStartupEvidence({...status,log:{...status.log,prints:[...status.log.prints,
      {clientScript:true,text:'ABYSS_UI failed startup: error'}]}},0), /runtime fault/);
    assert.throws(() => requireStartupEvidence({...status,state:'failed',error:'focus blocked'},0), /focus blocked/);
  } finally { rmSync(runDir,{recursive:true,force:true}); }
});
