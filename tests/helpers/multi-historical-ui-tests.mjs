import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/multi-historical-ui-tests.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'2e7959e46e03f7c351d2fff0d367435dd36330003c67e2911be3813ef637d41a');
export const multiHistoricalUiTests=JSON.parse(bytes);
export function preMultiHistoricalUiTest(path,source){
 const b=multiHistoricalUiTests.files[path];
 if(!b||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!==b.afterSha256)return source;
 const lines=normalized.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const before=lines.join('\n');assert.equal(hash(before),b.beforeSha256);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),normalized,'complete forward historical test composition');
 return before;
}
