import {preRawBindingSource} from './raw-binding-source.mjs';
// Exact test-only selector dependency-edge bridge; never changes current selection.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/selector-current-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'04eda9c205b093683c8a59a9b6e2da7f06fa4fac6abb1486974fb7a4a7a17ef4');
export const selectorCurrentSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
const b=selectorCurrentSourceProof;
assert.equal(b.path,'scripts/test-affected.mjs');
assert.equal(b.beforeCommit,'98fef95d047652aa6a8880241ddff28ef320a484');
assert.equal(b.afterCommit,'938194c32f233e77960adea2d8e4784fd98a8d0a');
assert.deepEqual(Object.keys(b.owners),['tests/helpers/current-game-ui-runner.mjs','tests/helpers/historical-card-input.mjs','tests/helpers/historical-monster-ui-runner.mjs','tests/helpers/current-phase-four-native.mjs']);
export function preSelectorCurrentSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preRawBindingSource(path,source,{readSource});
 if(path!==b.path||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUTF16Length||hash(text)!==b.afterSha256)return source;
 assert.equal(blob(text),b.afterGitBlob,'complete current selector Git blob');
 // These four imported owners provide the exact conditional fixture inventories.
 // Validate fresh caller-owned bytes every time, including after a warm projection.
 for(const [p,owner]of Object.entries(b.owners)){
  let actual;try{actual=readSource(p);}catch{assert.fail('selector linked source missing: '+p);}
  assert.equal(typeof actual,'string','selector linked source must exist: '+p);
  actual=normalize(actual);assert.equal(hash(actual),owner.sha256,'selector linked source identity: '+p);assert.equal(blob(actual),owner.gitBlob);
 }
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const prior=lines.join('\n');assert.equal(hash(prior),b.beforeSha256);assert.equal(blob(prior),b.beforeGitBlob);
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);lines.splice(h.beforeAt,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'complete selector forward equivalence');return prior;
}
