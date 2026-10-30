import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/feedback-actor-test-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'c204c76e95a2bc4c3ed7f339c6a865cca19caa4b532e8d68b77b6e9891bdb82c');
export const feedbackActorTestSource=JSON.parse(bytes);
export function preFeedbackActorTestSource(path,source){
 const b=feedbackActorTestSource;
 if(path!==b.path||typeof source!=='string')return source;
 const s=normalize(source);if(hash(s)!==b.afterSha256)return source;
 const lines=s.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const before=lines.join('\n');assert.equal(hash(before),b.beforeSha256);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),s);return before;
}
