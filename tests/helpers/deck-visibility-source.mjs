import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/deck-visibility-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'b81115b1c032b82d4f015f8de169eca157a9e48076c058c56b00622d5d8f401a');
export const deckVisibilitySourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const deckVisibilitySourcePaths=Object.freeze(Object.keys(deckVisibilitySourceProof.files));
assert.deepEqual(deckVisibilitySourcePaths,['src/lua/abyss_deck_ui.lua']);
export function preDeckVisibilitySource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=deckVisibilitySourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(hash(text)!==b.afterSha256)return source;
 for(const p of deckVisibilitySourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('deck-visibility linked source missing: '+p);}
  assert.equal(typeof live,'string','deck-visibility linked source must exist: '+p);
  assert.equal(hash(normalize(live)),deckVisibilitySourceProof.files[p].afterSha256,'deck-visibility linked source identity: '+p);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact deck-visibility forward source');return previous;
}
