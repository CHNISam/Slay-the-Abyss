// Exact outer projection; existing historical composition witnesses stay frozen.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/nested-command-snapshot-owner-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'03e37d4a5dc922e2014fd77a456eac1c988521e4f422172494f28b30d0ccd78d');
export const nestedSnapshotOwnerProof=JSON.parse(bytes);
assert.equal(nestedSnapshotOwnerProof.base,'ea13ede7bb4a8711d64eaf9a3ccbb3cd1fc61b8f');
export function preNestedSnapshotOwnerSource(path,source){
 if(typeof source!=='string')return source;
 source=normalize(source);
 const binding=nestedSnapshotOwnerProof.files[path];
 // Partial/unknown bytes stay exposed to the unchanged strict inner guard.
 if(!binding||hash(source)!==binding.afterSha256)return source;
 for(const change of binding.changes){
  assert.equal(source.split(change.after).length,2,'one exact nested snapshot owner delta');
  source=source.replace(change.after,change.before);
 }
 assert.equal(hash(source),binding.beforeSha256,'complete accepted parent source identity');
 return source;
}
