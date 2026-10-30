import {bindEntryRecognitionLengths} from './entry-recognition-lengths.mjs';
import {preFixtureConstructionSource} from './fixture-construction-source.mjs';
import {preCurrentEntrySource} from './current-entry-source.mjs';
import {preDeathAudioSource} from './death-audio-source.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/phase-four-runner-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'323f4f49a531c61f70691fc9cfd09f619e651bc785bec9aae8efea8d9b991360');
export const phaseFourRunnerProof=deepFreezeSourceProof(JSON.parse(bytes));
const recognitionLengths=bindEntryRecognitionLengths('phase-four-runner',bytes,{[phaseFourRunnerProof.path]:phaseFourRunnerProof});
export function prePhaseFourRunnerSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preCurrentEntrySource(path,source,{readSource});
 source=preDeathAudioSource(path,source,{readSource});
 const b=phaseFourRunnerProof;if(path!==b.path||typeof source!=='string')return source;
 // Length only rejects impossible matches; equal lengths retain every original identity and fresh-owner check.
 const text=normalize(source);if(text.length!==recognitionLengths[path]||hash(text)!==b.afterSha256)return source;
 for(const[p,entry]of Object.entries(b.linkedSources)){
  let actual;try{actual=preFixtureConstructionSource(p,readSource(p),{readSource});}catch{assert.fail('runner linked source missing: '+p);}
  assert.equal(typeof actual,'string','runner linked source must exist: '+p);
  const live=normalize(actual);assert.equal(hash(live),entry.sha256,'runner linked source identity: '+p);assert.equal(blob(live),entry.gitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text);return previous;
}
