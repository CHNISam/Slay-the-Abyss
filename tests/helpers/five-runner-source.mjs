import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/five-runner-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'bba544e03c0782a4ac70b9709c366477ffc813b19c8c2f6cbaef01a6535371bc');
export const fiveRunnerSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const fiveRunnerSourcePaths=Object.freeze(Object.keys(fiveRunnerSourceProof.files));
assert.deepEqual(fiveRunnerSourcePaths,["scripts/ci-test-timings.json", "scripts/verify-delivery.mjs"]);
export function preFiveRunnerSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=fiveRunnerSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of fiveRunnerSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('five-runner linked source missing: '+p);}
  assert.equal(typeof live,'string','five-runner linked source must exist: '+p);
  assert.equal(hash(normalize(live)),fiveRunnerSourceProof.files[p].afterSha256,'five-runner linked source identity: '+p);
  assert.equal(blob(normalize(live)),fiveRunnerSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact five-runner forward source');return previous;
}
