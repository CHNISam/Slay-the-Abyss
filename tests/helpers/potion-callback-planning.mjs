// Immutable local complete-run provenance and exact pure outer timing epoch.
// No live source reads, execution cache, or synthetic hosted observations.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
export const potionCallbackFloorKey='tests/potion-callback.test.mjs';
const receiptBytes=normalize(readFileSync(new URL('../../docs/evidence/potion-callback-planning-20261107.json',import.meta.url),'utf8'));
assert.equal(hash(receiptBytes),'436eaef9eea243cd593671d924535a78794f0c65e28b983adf4d9f99b66702c1','complete original and combined Potion observations');
const receipt=JSON.parse(receiptBytes),run=receipt.completedRun,original=receipt.originalObservation;
assert.equal(receipt.schemaVersion,1);assert.equal(receipt.kind,'local-complete-file-planning-floor');assert.equal(receipt.file,potionCallbackFloorKey);
assert.equal(receipt.baseRevision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
assert.equal(receipt.combinationBaseRevision,'0bc050279aae90b8e423a0d02f0c8ca56bf0331b');
assert.equal(receipt.potionOriginalHead,'e2ecb75160065d01535413704179c0c6c5ab6fa8');
assert.equal(receipt.potionOriginalTree,'e139808c32c3e6437551c92a3a30005e37510bcb');
assert.equal(hash(original.rawTap),original.logSha256);assert.equal(original.logSha256,'3f7a1c3f930c067f3c7dc5a2b166a55d134d2622a44af3c751bd136d297bdee2');
assert.equal(hash(run.rawTap),run.sha256);
for(const observation of [original,run]){
 for(const text of ['ℹ tests 10\n','ℹ pass 10\n','ℹ fail 0\n','ℹ cancelled 0\n','ℹ skipped 0\n'])assert(observation.rawTap.includes(text));
 assert.equal(Number(observation.rawTap.match(/ℹ duration_ms ([\d.]+)/)[1]),observation.runnerDurationMs??observation.durationMs);
}
assert.equal(original.runnerDurationMs,26590.905967);assert(original.durationMs>=original.runnerDurationMs);
assert.equal(original.durationMs,26661.777321);assert.equal(original.planningFloorMs,26662);
assert.equal(run.durationMs,29231.664342);assert.deepEqual([run.tests,run.passed,run.failed,run.cancelled,run.skipped,run.checkpoints,run.bytesPerSide,run.exitCode,run.signal],[10,10,0,0,0,31,23319377,0,null]);
assert.equal(receipt.durationMs,Math.ceil(Math.max(original.durationMs,run.durationMs)));
assert.equal(receipt.durationMs,29232);
assert.equal(Object.keys(receipt.sourceIdentity.handwrittenBefore).length,333);assert.equal(Object.keys(receipt.sourceIdentity.handwrittenAfter).length,334);
assert.equal(receipt.completeGraphStreams.length,2);assert.equal(receipt.completeGraphStreams[0].sha256,receipt.completeGraphStreams[1].sha256);
assert.equal(receipt.environment.platform,'linux');assert.match(receipt.environment.scope,/not a GitHub-hosted Linux or Windows observation/);
const beforeSource=normalize(readFileSync(new URL('./potion-callback-planning-before.json',import.meta.url),'utf8'));
assert.equal(hash(beforeSource),'39ad201a4b9bf0486820a23a95937a879a47092e2e07cf7ee848acd4a8f0ff14','complete unchanged Run catalogue timing predecessor');
assert.equal(receipt.beforeTimingsLfSha256,hash(beforeSource));
export function verifiedPotionCallbackFloor(){return {
  "durationMs": 29232,
  "environment": "local cloud Linux",
  "coverage": "10/10 complete file passed; 0 skipped; 31 complete-graph checkpoints",
  "kind": "Local complete-run planning estimate only; not a hosted Linux or Windows measurement.",
  "sourceLog": "build/potion-catalog-delivery/potion-complete.log",
  "sourceLogSha256": "385c2fb5042e1a2040c5134382fb1a4504d402e7b82790120f2fde8e780445d6",
  "sourceReceipt": "docs/evidence/potion-callback-planning-20261107.json",
  "sourceReceiptSha256": "436eaef9eea243cd593671d924535a78794f0c65e28b983adf4d9f99b66702c1"
};}
// Reconstruct the entire accepted after-source from the full previous source.
// All original nine floors and the Run catalogue floor must remain byte exact.
const expected=JSON.parse(beforeSource);
assert.equal(Object.keys(expected.jsPlanning.localLowerBounds).length,10);
assert.equal(Object.hasOwn(expected.jsPlanning.localLowerBounds,potionCallbackFloorKey),false);
expected.jsPlanning.localLowerBounds[potionCallbackFloorKey]=verifiedPotionCallbackFloor();
const afterSha256='ff45c2819a7000cea148d421305ab1afac780d0b71de1196b2dc68c69fb8fd66';
assert.equal(hash(JSON.stringify(expected,null,2)+'\n'),afterSha256);
export function prePotionCallbackPlanningSource(path,source){
 if(path!=='scripts/ci-test-timings.json'||typeof source!=='string'||hash(normalize(source))!==afterSha256)return source;
 return beforeSource;
}
