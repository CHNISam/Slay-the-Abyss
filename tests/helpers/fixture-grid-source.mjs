import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/fixture-grid-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'a4275c96f361944a40bdcb26c2d5fa1d54e75f5b94509daecc88c2c874e9e65e');
export const fixtureGridSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const fixtureGridSourcePaths=Object.freeze(Object.keys(fixtureGridSourceProof.files));
assert.deepEqual(fixtureGridSourcePaths,["tests/lua/support/game_ui_fixture.lua"]);
export function preFixtureGridSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=fixtureGridSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of fixtureGridSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('fixture-grid linked source missing: '+p);}
  assert.equal(typeof live,'string','fixture-grid linked source must exist: '+p);
  assert.equal(hash(normalize(live)),fixtureGridSourceProof.files[p].afterSha256,'fixture-grid linked source identity: '+p);
  assert.equal(blob(normalize(live)),fixtureGridSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact fixture-grid forward source');return previous;
}
