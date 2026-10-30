import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/fixture-construction-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'11b181e70433c9f6e527958bc0cd090380eb38922f76f1bf14e3e1f86b1f099e');
export const fixtureConstructionSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const fixtureConstructionSourcePaths=Object.freeze(Object.keys(fixtureConstructionSourceProof.files));
assert.deepEqual(fixtureConstructionSourcePaths,["tests/lua/support/game_ui_fixture.lua"]);
export function preFixtureConstructionSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=fixtureConstructionSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of fixtureConstructionSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('fixture-construction linked source missing: '+p);}
  assert.equal(typeof live,'string','fixture-construction linked source must exist: '+p);
  assert.equal(hash(normalize(live)),fixtureConstructionSourceProof.files[p].afterSha256,'fixture-construction linked source identity: '+p);
  assert.equal(blob(normalize(live)),fixtureConstructionSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact fixture-construction forward source');return previous;
}
