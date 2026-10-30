import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/final-ui-source.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'525d2e47914cf979ecca141bbaffba7168ec6b8adb1c433b6cc89ebfc9421f1e');
export const finalUiSourceProof=deepFreezeSourceProof(JSON.parse(bytes));
export const finalUiSourcePaths=Object.freeze(Object.keys(finalUiSourceProof.files));
assert.deepEqual(finalUiSourcePaths,["data/presentation/ui_theme.json", "scripts/controls-guide-layout.mjs", "scripts/exit-ui-layout.mjs", "src/lua/abyss_battle_intent_view.lua", "src/lua/abyss_game_ui.lua", "tests/lua/intent_formula.lua", "tests/lua/native_ui_parity.lua", "tests/native-ui-parity.test.mjs"]);
export function preFinalUiSource(path,source,{readSource=p=>readFileSync(p,'utf8')}={}){
 const b=finalUiSourceProof.files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(text.length!==b.afterUtf16Length||hash(text)!==b.afterSha256)return source;
 for(const p of finalUiSourcePaths){
  let live;try{live=readSource(p);}catch{assert.fail('final-ui linked source missing: '+p);}
  assert.equal(typeof live,'string','final-ui linked source must exist: '+p);
  assert.equal(hash(normalize(live)),finalUiSourceProof.files[p].afterSha256,'final-ui linked source identity: '+p);
  assert.equal(blob(normalize(live)),finalUiSourceProof.files[p].afterGitBlob);
 }
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);lines.splice(h.at,h.after.length,...h.before);}
 const previous=lines.join('\n');assert.equal(hash(previous),b.beforeSha256);assert.equal(blob(previous),b.beforeGitBlob);
 let delta=0;const forward=b.hunks.map(h=>{const at=h.at+delta;delta+=h.before.length-h.after.length;return {...h,at};});
 for(const h of forward.reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
 assert.equal(lines.join('\n'),text,'exact final-ui forward source');return previous;
}
