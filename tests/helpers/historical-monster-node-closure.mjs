import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const normalize=value=>value.replaceAll('\r\n','\n');
const bytes=gunzipSync(readFileSync(new URL('../fixtures/historical-monster-node-closure.json.gz',import.meta.url)));
assert.equal(hash(bytes),'b869a3badab292f02f0750669dc39f5937da11a68ad36e3578f63918a9b34d05','exact historical Node closure');
const proof=JSON.parse(bytes);
assert.equal(proof.baseCommit,'03266f668eb5ab6d7ed72d840fa55eafa90a819c');
export const historicalMonsterNodeInputs=Object.freeze([...new Set([...Object.keys(proof.helperInputs),...Object.keys(proof.files)])].sort());
export function verifiedHistoricalMonsterNodeClosure(read){
 // Fresh complete input checks, before exposing any historical replacement.
 for(const path of historicalMonsterNodeInputs){
  const expected=proof.files[path]?.afterSha256??proof.helperInputs[path];
  assert.equal(hash(normalize(read(path))),expected,'unreviewed historical Node helper: '+path);
 }
 const result=[];
 for(const [path,entry]of Object.entries(proof.files)){
  assert.equal(hash(entry.beforeSource),entry.beforeSha256,'historical Node target: '+path);
  result.push([path,entry.beforeSource]);
 }
 for(const [path,entry]of Object.entries(proof.documents)){
  const document=Buffer.from(entry.base64,'base64');
  assert.equal(hash(document),entry.sha256,'historical document target: '+path);
  result.push([path,document]);
 }
 return result;
}
