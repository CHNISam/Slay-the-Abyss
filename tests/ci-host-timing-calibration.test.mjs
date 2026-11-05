import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {ciHostTimingProof as proof,preCiHostTimingSource} from './helpers/ci-host-timing-source-inverse.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import {preCiCompleteCalibrationSource} from './helpers/ci-complete-calibration-source-inverse.mjs';
import {jsPlanningWeights,timings} from '../scripts/ci-shards.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const before=JSON.parse(proof.beforeSource),after=JSON.parse(proof.afterSource);

test('Host placement calibration contains only complete successful same-platform measurements and monotonic additions',()=>{
 assert.equal(proof.sourceHead,'8eae1c2e674cf01b85420d253cde67d9ef78fa2d');
 assert.equal(proof.beforeSha256,'1c1cecdc42cad10fc342e4051f88e911722a512712fc111e892691482b019bb1');
 assert.equal(proof.beforeGitBlob,'7d5132cbfc833ba1b3db362c537fb01219d1e6a0');
 const expected=structuredClone(before),observations=proof.provenance.observations,seen=new Set();
 assert.equal(observations.length,16);
 for(const row of observations){
  assert.equal(row.success,true);assert.equal(row.run,41958033163);assert.equal(row.head,proof.sourceHead);
  assert.ok(['win32','linux'].includes(row.platform));assert.ok(Number.isFinite(row.durationMs)&&row.durationMs>0);
  const key=row.platform+':'+row.file;assert.ok(!seen.has(key),'one complete observation per approved platform/file');seen.add(key);
  assert.match(row.rawLogSha256,/^[a-f0-9]{64}$/);assert.ok(Number.isSafeInteger(row.line)&&row.line>0);
  const match=row.rawLine.match(/CI_FILE_TIMING (\{.*\})/);assert.ok(match,'complete original reporter line');
  assert.deepEqual(JSON.parse(match[1]),{file:row.file,durationMs:row.durationMs,success:true});
  assert.match(row.url,new RegExp('/actions/runs/41958033163/job/'+row.job+'$'));
  assert.ok(proof.update.sourceRecords.some(record=>record.jobId===row.job&&record.sha256===row.rawLogSha256&&record.path===row.rawLog));
  expected.js[row.platform][row.file]=Math.max(before.js[row.platform][row.file]??before.unknownJsMs,Math.ceil(row.durationMs));
 }
 assert.deepEqual(proof.update.observedFileCounts,{win32:8,linux:8});
 assert.deepEqual(proof.update.raisedCounts,{win32:8,linux:8});
 assert.equal(proof.update.previousMapSha256,hash(JSON.stringify(before.js)));
 assert.equal(proof.update.resultingMapSha256,hash(JSON.stringify(expected.js)));
 expected.jsCalibrationUpdates.push(proof.update);
 assert.equal(JSON.stringify(expected,null,2)+'\n',proof.afterSource,'no unrelated value, metadata, ordering or spelling change');
 assert.equal(preCiCompleteCalibrationSource(proof.path,readFileSync(proof.path,'utf8').replaceAll('\r\n','\n')),proof.afterSource,'actual source projects to this complete approved historical epoch');
 for(const platform of ['win32','linux'])for(const [file,value]of Object.entries(before.js[platform]))assert.ok(after.js[platform][file]>=value);
 assert.equal(after.js.linux['tests/game-ui-host-modal.test.mjs'],undefined,'unfinished Linux family is not fabricated');
 assert.equal(after.js.win32['tests/game-ui-host-result.test.mjs'],undefined,'unfinished Windows family is not fabricated');
 for(const key of Object.keys(before).filter(key=>key!=='js'&&key!=='jsCalibrationUpdates'))assert.deepEqual(after[key],before[key],key+' remains unchanged');
});

test('only the complete approved Host timing source reverses, including through the historical integration entry',()=>{
 for(const source of [proof.afterSource,proof.afterSource.replaceAll('\n','\r\n')]){
  assert.equal(preCiHostTimingSource(proof.path,source),proof.beforeSource);
  assert.equal(preIntegrationSource(proof.path,source,'base',{readSource(){assert.fail('timing inverse has no linked live owner');}}),proof.beforeSource);
 }
 for(const value of [proof.beforeSource,undefined,null,{},123])assert.equal(preCiHostTimingSource(proof.path,value),value);
 assert.equal(preCiHostTimingSource('scripts/other.json',proof.afterSource),proof.afterSource);
});

test('wrong measured values, duplicate positions, spelling changes, partial input and unrelated drift never gain the old identity',()=>{
 const mutations=[proof.afterSource+'\n',proof.afterSource.slice(0,-10),proof.afterSource.replace('"unknownJsMs": 10000','"unknownJsMs": 10001'),
  proof.afterSource.replace('"unknownJsMs": 10000','"unknownJsMs": 10000,\n  "unknownJsMs": 10000')];
 for(const row of proof.provenance.observations){
  const value=after.js[row.platform][row.file],entry=JSON.stringify(row.file)+': '+value;
  assert.equal(proof.afterSource.split(entry).length,2,'one approved map position');
  mutations.push(proof.afterSource.replace(entry,JSON.stringify(row.file)+': '+(value+1)));
  mutations.push(proof.afterSource.replace(entry,entry+',\n      '+entry));
  mutations.push(proof.afterSource.replace(entry,JSON.stringify(row.file)+': '+value+'.0'));
 }
 for(const mutation of mutations){
  assert.notEqual(mutation,proof.afterSource);
  assert.equal(preCiHostTimingSource(proof.path,mutation),mutation);
  assert.notEqual(hash(preCiHostTimingSource(proof.path,mutation)),proof.beforeSha256);
 }
});

test('TASK-75.4 calibration preserves unknown fallback, worker safety and execution data independently of Full shape',()=>{
 assert.deepEqual(JSON.parse(preCiCompleteCalibrationSource(proof.path,readFileSync(proof.path,'utf8'))),after);
 for(const platform of ['win32','linux']){
  assert.equal(jsPlanningWeights(['tests/unmeasured-host-family.test.mjs'],platform)['tests/unmeasured-host-family.test.mjs'],before.unknownJsMs);
 }
 assert.deepEqual(after.lua,before.lua);assert.deepEqual(after.luaShard,before.luaShard);
 assert.deepEqual(after.initialMs,before.initialMs);assert.deepEqual(after.jsPlanning,before.jsPlanning);
});
