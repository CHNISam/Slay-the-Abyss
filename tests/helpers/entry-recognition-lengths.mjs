import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/entry-recognition-lengths.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'3574327c89de160a0da49f9de8b2a0af5656f1dbac63f2fb2387fccfeb076cdc','complete Git-derived entry recognition lengths');
export const entryRecognitionLengths=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(entryRecognitionLengths.schemaVersion,1);
assert.equal(entryRecognitionLengths.normalization,'CRLF-to-LF');
assert.equal(entryRecognitionLengths.measure,'UTF-16-code-units');
export function bindEntryRecognitionLengths(group,proofBytes,bindings){
 const witness=entryRecognitionLengths.groups[group];assert.ok(witness);
 assert.equal(hash(proofBytes),witness.proofSha256,'original entry proof identity: '+group);
 assert.deepEqual(Object.keys(witness.files),Object.keys(bindings));
 const lengths={};
 for(const [path,b]of Object.entries(bindings)){
  const record=witness.files[path];assert.equal(record.afterSha256,b.afterSha256);
  assert.equal(record.afterGitBlob,b.afterGitBlob);
  assert.ok(Number.isSafeInteger(record.utf16Length)&&record.utf16Length>=0);
  lengths[path]=record.utf16Length;
 }
 return Object.freeze(lengths);
}
