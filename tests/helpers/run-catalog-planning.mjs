import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export const runCatalogFloorKey="tests/run-catalog-responsibilities.test.mjs";
export function verifiedRunCatalogFloor(){
 const bytes=readFileSync(new URL('../../docs/evidence/run-catalog-planning-20261107.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
 assert.equal(hash(bytes),'7f9979256080cee4e4df92c8d97a45fbf82228d2891e999720d8f270f74ec7e3');
 const receipt=JSON.parse(bytes),run=receipt.completedRun;
 assert.equal(receipt.schemaVersion,1);assert.equal(receipt.kind,'local-complete-file-planning-floor');assert.equal(receipt.file,runCatalogFloorKey);
 assert.equal(receipt.beforeTimingsLfSha256,'a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24');assert.equal(receipt.durationMs,71327);
 assert.equal(hash(run.rawTap),run.sha256);
 for(const text of ['ℹ tests 14\n','ℹ pass 14\n','ℹ fail 0\n','ℹ skipped 0\n'])assert(run.rawTap.includes(text));
 assert.equal(Number(run.rawTap.match(/ℹ duration_ms ([\d.]+)/)[1]),71326.726364);assert.equal(run.durationMs,71326.726364);assert.equal(Math.ceil(run.durationMs),receipt.durationMs);
 assert.deepEqual([run.tests,run.passed,run.failed,run.skipped,run.checkpoints,run.bytesPerSide],[14,14,0,0,264,48319157]);
 assert.equal(receipt.sourceIdentity.selectedFiles.length,6);assert(receipt.sourceIdentity.selectedFiles.some(f=>f.path===runCatalogFloorKey));
 assert.equal(receipt.environment.platform,'linux');assert.match(receipt.environment.scope,/not a GitHub-hosted Linux or Windows observation/);
 return {
  "durationMs": 71327,
  "environment": "local cloud Linux",
  "coverage": "14/14 complete file passed; 0 skipped; complete-graph observer",
  "kind": "Local complete-run planning estimate only; not a hosted Linux or Windows measurement.",
  "sourceLog": "build/catalog-final-tests.log",
  "sourceLogSha256": "93be917d80bf8d66c844b590c237d97c3812ab9e2ac6f6ac225b46a5bf1f8853",
  "sourceReceipt": "docs/evidence/run-catalog-planning-20261107.json",
  "sourceReceiptSha256": "7f9979256080cee4e4df92c8d97a45fbf82228d2891e999720d8f270f74ec7e3"
};
}
