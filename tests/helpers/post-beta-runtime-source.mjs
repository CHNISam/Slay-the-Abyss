import {preFiveRunnerSource} from './five-runner-source.mjs';
import {preMonsterInventorySource} from './monster-inventory-source.mjs';
import {preRawBindingSource,rawBindingSourcePaths} from './raw-binding-source.mjs';
import {bindEntryRecognitionLengths} from './entry-recognition-lengths.mjs';
import {preFinalUiSource,finalUiSourcePaths} from './final-ui-source.mjs';
import {preP0UiSource,p0UiSourcePaths} from './p0-ui-source.mjs';
import {preBetaCurrentTestSource} from './beta-current-test-source.mjs';
import {preArtifactRuntimeSource,artifactRuntimePaths} from './artifact-runtime-source.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/post-beta-runtime-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'0609382f7314de67936162274faa7c0de381c37f39c79ed16071404b389dff0a');
export const postBetaRuntimeProof=deepFreezeSourceProof(JSON.parse(bytes));
export const postBetaRuntimePaths=Object.freeze(Object.keys(postBetaRuntimeProof.files));
export const postBetaRuntimeHistoricalPaths=Object.freeze([...new Set([...rawBindingSourcePaths,...finalUiSourcePaths,...p0UiSourcePaths,'scripts/test-lua.mjs','tests/lua/game_ui.lua','src/lua/abyss_feedback.lua',...artifactRuntimePaths,...postBetaRuntimePaths])].sort());
assert.deepEqual(postBetaRuntimePaths,['src/lua/abyss_battle_render_actors.lua','src/lua/abyss_feedback_actor_painter.lua']);
const recognitionLengths=bindEntryRecognitionLengths('post-beta-runtime',bytes,postBetaRuntimeProof.files);
export function prePostBetaRuntimeSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preFiveRunnerSource(path,source,{readSource});
 source=preMonsterInventorySource(path,source,{readSource});
 source=preRawBindingSource(path,source,{readSource});
 source=preFinalUiSource(path,source,{readSource});
 source=preP0UiSource(path,source,{readSource});
 source=preBetaCurrentTestSource(path,source,{readSource});
 source=preArtifactRuntimeSource(path,source,{readSource});
 const b=postBetaRuntimeProof.files[path];if(!b||typeof source!=='string')return source;
 // Length only rejects impossible matches; equal lengths retain every original identity and fresh-owner check.
 const text=normalize(source);if(text.length!==recognitionLengths[path]||hash(text)!==b.afterSha256)return source;
 for(const p of postBetaRuntimePaths){
  let live;try{live=preArtifactRuntimeSource(p,readSource(p),{readSource});}catch{assert.fail('post-beta linked source missing: '+p);}
  assert.equal(typeof live,'string','post-beta linked source must exist: '+p);
  assert.equal(hash(normalize(live)),postBetaRuntimeProof.files[p].afterSha256,'post-beta linked source identity: '+p);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact post-beta forward source');return previous;
}
