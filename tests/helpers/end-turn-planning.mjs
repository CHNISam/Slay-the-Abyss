import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export const endTurnFloorKey="tests/end-turn-responsibilities.test.mjs";
export function verifiedEndTurnFloor(){
 const bytes=readFileSync(new URL('../../docs/evidence/end-turn-planning-20261107.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
 assert.equal(hash(bytes),'2f59e5322ec6abfc7b9cc168734ea0f5333197a9f39ee4d75237ed6d9ddbf537');
 const receipt=JSON.parse(bytes),run=receipt.completedRun;
 assert.equal(receipt.schemaVersion,1);assert.equal(receipt.kind,'local-complete-file-planning-floor');assert.equal(receipt.file,endTurnFloorKey);
 assert.equal(receipt.beforeTimingsLfSha256,'a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24');assert.equal(receipt.durationMs,21279);
 assert.equal(hash(run.rawTap),run.sha256);
 for(const text of ['ℹ tests 12\n','ℹ pass 12\n','ℹ fail 0\n','ℹ skipped 0\n'])assert(run.rawTap.includes(text));
 assert.equal(Number(run.rawTap.match(/ℹ duration_ms ([\d.]+)/)[1]),21278.770844);assert.equal(run.durationMs,21278.770844);assert.equal(Math.ceil(run.durationMs),receipt.durationMs);
 assert.deepEqual([run.tests,run.passed,run.failed,run.skipped,run.checkpoints,run.bytesPerSide],[12,12,0,0,391,9028545]);
 assert.equal(receipt.sourceIdentity.selectedFiles.length,7);assert(receipt.sourceIdentity.selectedFiles.some(f=>f.path===endTurnFloorKey));
 assert.equal(receipt.environment.platform,'linux');assert.match(receipt.environment.scope,/not a GitHub-hosted Linux or Windows observation/);
 return {
  "durationMs": 21279,
  "environment": "local cloud Linux",
  "coverage": "12/12 complete file passed; 0 skipped; complete-graph observer",
  "kind": "Local complete-run planning estimate only; not a hosted Linux or Windows measurement.",
  "sourceLog": "build/end-turn-first-tests.log",
  "sourceLogSha256": "1be350bbc484314e255f0b2cbd916747a5144c5dc959f2730c7525fb758bd4de",
  "sourceReceipt": "docs/evidence/end-turn-planning-20261107.json",
  "sourceReceiptSha256": "2f59e5322ec6abfc7b9cc168734ea0f5333197a9f39ee4d75237ed6d9ddbf537"
};
}
