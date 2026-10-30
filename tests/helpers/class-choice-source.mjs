import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/class-choice-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'2bf49e0597e2d11f01e8605c863caee8be1ea5216281a93551c2dc900d3f9c73');
export const classChoiceSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const classChoiceSourcePaths=Object.freeze(Object.keys(classChoiceSourceProof.files));
assert.deepEqual(classChoiceSourcePaths,["tests/lua/game_ui_class_choices.lua"]);
export function preClassChoiceSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=classChoiceSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of classChoiceSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('class-choice linked source missing: '+p);}
  assert.equal(typeof live,'string','class-choice linked source must exist: '+p);
  assert.equal(hash(normalize(live)),classChoiceSourceProof.files[p].afterSha256,'class-choice linked source identity: '+p);
  assert.equal(blob(normalize(live)),classChoiceSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact class-choice forward source');return previous;
}
