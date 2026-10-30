import {bindRuntimeRecognitionLengths} from './runtime-recognition-lengths.mjs';
import {preFinalUiSource} from './final-ui-source.mjs';
import {prePhaseFourRunnerSource} from './phase-four-runner-source.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/artifact-runtime-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'20cba0f320fa855c3ad6a50150926a743a0cc251579d28a50bc1507b13cf9a36');
export const artifactRuntimeProof=deepFreezeSourceProof(JSON.parse(bytes));
export const artifactRuntimePaths=Object.freeze(Object.keys(artifactRuntimeProof.files));
assert.deepEqual(artifactRuntimePaths,["src/lua/abyss_battle_intent_view.lua", "src/lua/abyss_battle_render_actors.lua", "src/lua/abyss_battle_ui.lua", "src/lua/abyss_monster_intent_particle_view.lua"]);
const recognitionLengths=bindRuntimeRecognitionLengths('artifact-runtime',bytes,artifactRuntimeProof.files);
export function preArtifactRuntimeSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preFinalUiSource(path,source,{readSource});
 source=prePhaseFourRunnerSource(path,source,{readSource});
 const b=artifactRuntimeProof.files[path];if(!b||typeof source!=='string')return source;
 // Length rejects impossible matches only; all equal-length identity and fresh-owner checks remain.
 const text=normalize(source);if(text.length!==recognitionLengths[path]||hash(text)!==b.afterSha256)return source;
 for(const p of artifactRuntimePaths){
  let live;try{live=preFinalUiSource(p,readSource(p),{readSource});}catch{assert.fail('artifact linked source missing: '+p);}
  assert.equal(typeof live,'string','artifact linked source must exist: '+p);
  assert.equal(hash(normalize(live)),artifactRuntimeProof.files[p].afterSha256,'artifact linked source identity: '+p);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact artifact forward source');return previous;
}
