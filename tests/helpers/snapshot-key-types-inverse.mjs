import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

const bytes=readFileSync(new URL('../fixtures/snapshot-key-types-20261104.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(createHash('sha256').update(bytes).digest('hex'),'c0c388d06ea47051362f17c8fef568688dccff6e6cdac3a5a810167698c7ba1d');
export const keyTypesProof=JSON.parse(bytes);

// Only these two complete blocks may precede the existing frozen traversal
// inverse. Unrelated source drift stays visible to its original golden hash.
export function beforeSnapshotKeyTypes(source){
 let result=source.replaceAll('\r\n','\n');
 for(const change of keyTypesProof.changes){
  assert.equal(result.split(change.after).length,2,'exact unique snapshot key-type cache block');
  result=result.replace(change.after,change.before);
 }
 return result;
}
