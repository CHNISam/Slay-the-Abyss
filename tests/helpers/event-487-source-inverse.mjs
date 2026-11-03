// Test-only exact inverse; production always uses the current source.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/event-487-source-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'d26cd94526b156d432f7f3479356a0a4a7323f6ac8064170360e435d36da628c','complete event inverse proof identity');
const proof=JSON.parse(bytes);
export function preEvent487Source(path,source){
 if(path!==proof.path||typeof source!=='string')return source;
 const text=source.replaceAll('\r\n','\n');
 if(hash(text)!==proof.afterSha256)return source;
 const lines=text.split('\n');assert.equal(lines.length,proof.afterLines);
 for(const h of [...proof.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact event inverse hunk');lines.splice(h.at,h.after.length,...h.before);}
 const prior=lines.join('\n');assert.equal(lines.length,proof.beforeLines);assert.equal(hash(prior),proof.beforeSha256,'complete historical event source identity');
 const forward=[...lines];for(const h of [...proof.hunks].reverse()){assert.deepEqual(forward.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);forward.splice(h.beforeAt,h.before.length,...h.after);}
 assert.equal(forward.join('\n'),text,'exact event forward identity');return prior;
}
