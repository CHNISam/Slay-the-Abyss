import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/death-audio-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'8bd5bd88a7fe88149309891e3967a4051f8c6c9978ca38d69ffdccfb86458a0f');
export const deathAudioSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const deathAudioSourcePaths=Object.freeze(Object.keys(deathAudioSourceProof.files));
assert.deepEqual(deathAudioSourcePaths,['src/lua/abyss_feedback.lua']);
export function preDeathAudioSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=deathAudioSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(hash(text)!==b.afterSha256)return source;
 for(const p of deathAudioSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('death-audio linked source missing: '+p);}
  assert.equal(typeof live,'string','death-audio linked source must exist: '+p);
  assert.equal(hash(normalize(live)),deathAudioSourceProof.files[p].afterSha256,'death-audio linked source identity: '+p);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact death-audio forward source');return previous;
}
