import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/phase-three-memory-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'a741adc4ec5d5cfc7adde8a4bf28666f1d62c67cd82c71fd425b66229dd2df66');
export const phaseThreeMemorySourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const phaseThreeMemorySourcePaths=Object.freeze(Object.keys(phaseThreeMemorySourceProof.files));
assert.deepEqual(phaseThreeMemorySourcePaths,["scripts/test-affected.mjs", "scripts/test-lua.mjs"]);
export function prePhaseThreeMemorySource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=phaseThreeMemorySourceProof.files[path];if(!b||typeof source!=='string')return source;
 // Length rejects impossible matches only; all equal-length identity and fresh-owner checks remain.
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of phaseThreeMemorySourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('phase-three-memory linked source missing: '+p);}
  assert.equal(typeof live,'string','phase-three-memory linked source must exist: '+p);
  assert.equal(hash(normalize(live)),phaseThreeMemorySourceProof.files[p].afterSha256,'phase-three-memory linked source identity: '+p);
  assert.equal(blob(normalize(live)),phaseThreeMemorySourceProof.files[p].afterGitBlob,'phase-three-memory linked source Git blob: '+p);
 }
 for(const[p,entry]of Object.entries(phaseThreeMemorySourceProof.linkedSources)){
  let actual;try{actual=readSource(p);}catch{assert.fail('phase-three-memory linked source missing: '+p); }
  assert.equal(typeof actual,'string','phase-three-memory linked source must exist: '+p);
  const live=normalize(actual);assert.equal(live.length,entry.utf16Length,'phase-three-memory linked source length: '+p);assert.equal(hash(live),entry.sha256,'phase-three-memory linked source identity: '+p);assert.equal(blob(live),entry.gitBlob,'phase-three-memory linked source Git blob: '+p);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact phase-three-memory forward source');return previous;
}
