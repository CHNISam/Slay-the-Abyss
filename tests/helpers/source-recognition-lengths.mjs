import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/source-recognition-lengths.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'adc0d0a1e6f9aab0626e277f6a6b16e1b428d94f2cae1290a28dee43b44c5a8b','complete Git-derived recognition lengths');
export const sourceRecognitionLengths=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(sourceRecognitionLengths.schemaVersion,1);
assert.equal(sourceRecognitionLengths.normalization,'CRLF-to-LF');
assert.equal(sourceRecognitionLengths.measure,'UTF-16-code-units');
export function bindRecognitionLengths(group,proofBytes,bindings,digestKey){
 const witness=sourceRecognitionLengths.groups[group];assert.ok(witness);
 assert.equal(hash(proofBytes),witness.proofSha256,'original proof identity: '+group);
 assert.deepEqual(Object.keys(witness.files),Object.keys(bindings));
 const lengths={};
 for(const[path,b]of Object.entries(bindings)){
  const record=witness.files[path];assert.equal(record.sha256,b[digestKey]);
  assert.match(record.gitBlob,/^[a-f0-9]{40}$/);assert.ok(Number.isSafeInteger(record.utf16Length)&&record.utf16Length>=0);
  lengths[path]=record.utf16Length;
 }
 return Object.freeze(lengths);
}
