import {preBetaCurrentTestSource} from './beta-current-test-source.mjs';
// Historical-only exact bridge to the independently archived PR381 host.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preDeliverySource} from './delivery-source-composition.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/beta-ui-historical-host.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'7c08cd9b5ba01a0495d7272335f9bc877d9bdc509f7d9d8f9c314cb898700dfd');
const proof=JSON.parse(bytes);
export function preBetaHostSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preBetaCurrentTestSource(path,source,{readSource});
 source=preDeliverySource(path,source,{readSource});
 if(path!==proof.path||typeof source!=='string'||hash(normalize(source))!==proof.fromSha256)return source;
 const original=normalize(source),lines=original.split('\n');
 for(const h of [...proof.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before,'exact historical UI host hunk');
  lines.splice(h.at,h.before.length,...h.after);
 }
 const result=lines.join('\n');assert.equal(hash(result),proof.toSha256,'complete historical UI host');
 let delta=0;const forward=proof.hunks.map(h=>{const at=h.at+delta;delta+=h.after.length-h.before.length;return {...h,at};});
 for(const h of forward.reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);
  lines.splice(h.at,h.after.length,...h.before);
 }
 assert.equal(lines.join('\n'),original,'historical UI bridge is bidirectional');
 return result;
}
