import {prePhaseThreeMemorySource} from './phase-three-memory-source.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/raw-binding-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'0b884288a2423c14468e4be81508c12217383e79a29d7a3433e4a555289231a9');
export const rawBindingSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const rawBindingSourcePaths=Object.freeze(Object.keys(rawBindingSourceProof.files));
assert.deepEqual(rawBindingSourcePaths,["scripts/test-affected.mjs", "scripts/test-lua.mjs", "tests/lua/controller_host.lua", "tests/lua/game_ui_phase_four.lua", "tests/lua/support/potion_gesture_fixture.lua"]);
export function preRawBindingSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=prePhaseThreeMemorySource(path,source,{readSource});
 const b=rawBindingSourceProof.files[path];if(!b||typeof source!=='string')return source;
 // Length rejects impossible matches only; all equal-length identity and fresh-owner checks remain.
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of rawBindingSourcePaths){
  let live;try{live=prePhaseThreeMemorySource(p,readSource(p),{readSource});}catch{assert.fail('raw-binding linked source missing: '+p);}
  assert.equal(typeof live,'string','raw-binding linked source must exist: '+p);
  assert.equal(hash(normalize(live)),rawBindingSourceProof.files[p].afterSha256,'raw-binding linked source identity: '+p);
  assert.equal(blob(normalize(live)),rawBindingSourceProof.files[p].afterGitBlob);
 }
 for(const[p,entry]of Object.entries(rawBindingSourceProof.linkedSources)){
  let actual;try{actual=readSource(p);}catch{assert.fail('raw-binding linked source missing: '+p); }
  assert.equal(typeof actual,'string','raw-binding linked source must exist: '+p);
  const live=normalize(actual);assert.equal(live.length,entry.utf16Length,'raw-binding linked source length: '+p);assert.equal(hash(live),entry.sha256,'raw-binding linked source identity: '+p);assert.equal(blob(live),entry.gitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact raw-binding forward source');return previous;
}
