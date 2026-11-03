// Test-only exact inverse; production always uses the current source.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/event-488-source-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'5cde7ee4add3bdee59a9c76eafc3d876b10be3ac5e3c4c296e6b36b3ebf54df4','complete event inverse proof identity');
const proof=JSON.parse(bytes);
export function preEvent488Source(path,source){
 if(path!==proof.path||typeof source!=='string')return source;
 const text=source.replaceAll('\r\n','\n');
 if(hash(text)!==proof.afterSha256)return source;
 const lines=text.split('\n');assert.equal(lines.length,proof.afterLines);
 for(const h of [...proof.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact event inverse hunk');lines.splice(h.at,h.after.length,...h.before);}
 const prior=lines.join('\n');assert.equal(lines.length,proof.beforeLines);assert.equal(hash(prior),proof.beforeSha256,'complete historical event source identity');
 const forward=[...lines];for(const h of [...proof.hunks].reverse()){assert.deepEqual(forward.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);forward.splice(h.beforeAt,h.before.length,...h.after);}
 assert.equal(forward.join('\n'),text,'exact event forward identity');return prior;
}
