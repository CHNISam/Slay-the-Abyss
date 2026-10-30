import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/p0-deck-recognition-lengths.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'c4c4079de5c6508516113a58931bee3ac6c7c82f08e4d85d07c187f44287ff55','complete Git-derived P0/deck recognition lengths');
export const p0DeckRecognitionLengths=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(p0DeckRecognitionLengths.schemaVersion,1);
assert.equal(p0DeckRecognitionLengths.normalization,'CRLF-to-LF');
assert.equal(p0DeckRecognitionLengths.measure,'UTF-16-code-units');
export function bindP0DeckRecognitionLengths(group,proofBytes,bindings){
 const witness=p0DeckRecognitionLengths.groups[group];assert.ok(witness);
 assert.equal(hash(proofBytes),witness.proofSha256,'original P0/deck proof identity: '+group);
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
