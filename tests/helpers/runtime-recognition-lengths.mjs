import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/runtime-recognition-lengths.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'c6e1bffb6e5939164aed850db6911b5dce7041435d27a96b445cef045dc4c8c2','complete Git-derived runtime recognition lengths');
export const runtimeRecognitionLengths=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(runtimeRecognitionLengths.schemaVersion,1);
assert.equal(runtimeRecognitionLengths.normalization,'CRLF-to-LF');
assert.equal(runtimeRecognitionLengths.measure,'UTF-16-code-units');
export function bindRuntimeRecognitionLengths(group,proofBytes,bindings){
 const witness=runtimeRecognitionLengths.groups[group];assert.ok(witness);
 assert.equal(hash(proofBytes),witness.proofSha256,'original runtime proof identity: '+group);
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
