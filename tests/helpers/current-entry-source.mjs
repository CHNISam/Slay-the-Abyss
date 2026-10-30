import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/current-entry-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'4082c51d6a34d6f3e8d4971bf3fda1384ed9397bfa448cccbab163b81181a5c2');
export const currentEntrySourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const currentEntrySourcePaths=Object.freeze(Object.keys(currentEntrySourceProof.files));
assert.deepEqual(currentEntrySourcePaths,['scripts/test-lua.mjs','tests/lua/game_ui.lua']);
export function preCurrentEntrySource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=currentEntrySourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(hash(text)!==b.afterSha256)return source;
 for(const p of currentEntrySourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('current-entry linked source missing: '+p);}
  assert.equal(typeof live,'string','current-entry linked source must exist: '+p);
  assert.equal(hash(normalize(live)),currentEntrySourceProof.files[p].afterSha256,'current-entry linked source identity: '+p);
 }
 for(const[p,entry]of Object.entries(currentEntrySourceProof.linkedSources)){
  let actual;try{actual=readSource(p);}catch{assert.fail('current-entry linked source missing: '+p);}
  assert.equal(typeof actual,'string','current-entry linked source must exist: '+p);
  const live=normalize(actual);assert.equal(hash(live),entry.sha256,'current-entry linked source identity: '+p);assert.equal(blob(live),entry.gitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact current-entry forward source');return previous;
}
