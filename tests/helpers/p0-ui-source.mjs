import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/p0-ui-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'2f7b6e18bc22f2db81ecbf7391e1ba703f006eff67136c5169e6eedb25a71110');
export const p0UiSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const p0UiSourcePaths=Object.freeze(Object.keys(p0UiSourceProof.files));
assert.deepEqual(p0UiSourcePaths,["data/presentation/ui_theme.json", "scripts/exit-ui-layout.mjs", "scripts/ui-layout.mjs", "src/lua/abyss_game_ui.lua", "tests/exit-ui-layout.test.mjs", "tests/native-ui-parity.test.mjs", "tests/ui-layout.test.mjs"]);
export function preP0UiSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=p0UiSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(hash(text)!==b.afterSha256)return source;
 for(const p of p0UiSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('p0-ui linked source missing: '+p);}
  assert.equal(typeof live,'string','p0-ui linked source must exist: '+p);
  assert.equal(hash(normalize(live)),p0UiSourceProof.files[p].afterSha256,'p0-ui linked source identity: '+p);
  assert.equal(blob(normalize(live)),p0UiSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact p0-ui forward source');return previous;
}
