import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { sha256 } from '../scripts/evidence-files.mjs';
import { requireStartupEvidence } from '../scripts/native-playtest-evidence.mjs';

test('startup uses raw decoding and actual run request, not claimed metadata',()=>{
  const runDir=mkdtempSync(join(tmpdir(),'abyss-run-')),runId=runDir.split(/[\\/]/).at(-1);
  const mapPath=join(runDir,'candidate.gil'),file=join(runDir,'log.gia');
  writeFileSync(mapPath,'fixture candidate');
  const prints=[{clientScript:true,text:'ABYSS_BUILD fixture-build'},{clientScript:true,text:'ABYSS_UI ready'}];
  // Explicit JSON format test double. The production CLI injects MCP inspectDebugLog.
  const decodeLog=bytes=>({sourceHash:sha256(bytes),prints:JSON.parse(bytes),nextOffset:null});
  const save=rows=>writeFileSync(file,JSON.stringify(rows));save(prints);
  writeFileSync(join(runDir,'request.json'),JSON.stringify({runDir,mapPath,clientScriptLog:true}));
  const expected={runDir,runId,mapPath,buildId:'fixture-build',candidateHash:sha256(readFileSync(mapPath)),startedAt:0};
  const status={state:'succeeded',runId,runDir,steps:[{step:'log-subscribed',clientScripts:true}],log:{file,prints}};
  const check=(value=status,context=expected)=>requireStartupEvidence(value,context,{decodeLog,parserVersion:'fixture-json-v1'});
  try {
    assert.equal(check().status,'pass');
    assert.throws(()=>check({...status,steps:[]}),/subscription/);
    assert.throws(()=>check({...status,runId:'wrong'}),/another run/);
    assert.throws(()=>check(status,{...expected,candidateHash:'f'.repeat(64)}),/candidate/);
    assert.throws(()=>check(status,{...expected,startedAt:Date.now()+10000}),/Stale/);
    assert.throws(()=>check({...status,log:{...status.log,prints:[prints[1]]}}),/differ/);
    assert.throws(()=>check(status,{...expected,buildId:'old'}),/never reached ready/);
    save([]);assert.throws(()=>check(),/differ/);
    writeFileSync(file,'');assert.throws(()=>check(),/Empty/);
    const faults=[...prints,{clientScript:true,text:'ABYSS_UI failed startup: fixture'}];save(faults);
    assert.throws(()=>check({...status,log:{file,prints:faults}}),/runtime fault/);
    save(prints);assert.equal(check().status,'pass');
  } finally {rmSync(runDir,{recursive:true,force:true});}
});
