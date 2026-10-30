import {preIntegrationSource} from './pr372-integration-source.mjs';
// Test-only exact outer layer for the hand gesture (flick) + STS aim arrow slice.
// Old witnesses keep their full bytes; unknown edits remain visible to their guards.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('./hand-gesture-aim-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'7478ca2465020478f6ff9ea5a9ba3f5136763a4f640968fcff4cff262f63bbab','complete hand-gesture aim outer source identity');
export const handGestureAimSourceLayer=JSON.parse(bytes);
assert.equal(handGestureAimSourceLayer.schemaVersion,1);
assert.equal(handGestureAimSourceLayer.baseCommit,'9293405dfa07be95c632ac1a15cc4ebc2fb3034b');
export const handGestureAimAddedPaths=Object.freeze([]);
assert.deepEqual(Object.keys(handGestureAimSourceLayer.files),[
  'src/lua/abyss_battle_card_gestures.lua','src/lua/abyss_battle_card_view.lua',
  'tests/aim-visual-parity.test.mjs','tests/lua/aim_visual_parity.lua','tests/lua/m3_ui_polish.lua',...handGestureAimAddedPaths,
]);
for(const [path,binding]of Object.entries(handGestureAimSourceLayer.files)){
  assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
  assert.equal(binding.beforeSha256===null,handGestureAimAddedPaths.includes(path),'only the intent module is new');
  if(binding.beforeSha256===null)assert.deepEqual(binding.hunks,[]);
}
export function preHandGestureAimSource(path,source,{readSource=path=>readFileSync(path,'utf8')}={}){
 source=preIntegrationSource(path,source,'aim');
  const binding=handGestureAimSourceLayer.files[path];
  if(!binding||typeof source!=='string')return source;
  const normalized=normalize(source);
  if(hash(normalized)!==binding.afterSha256)return source;
  for(const added of handGestureAimAddedPaths){
    let actual;
    try{actual=readSource(added);}catch{assert.fail('unreviewed hand-gesture linked module missing: '+added);}
    assert.equal(hash(normalize(actual)),handGestureAimSourceLayer.files[added].afterSha256,'unreviewed hand-gesture linked module drift: '+added);
  }
  if(binding.beforeSha256===null)return null;
  const lines=normalized.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact hand-gesture inverse hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const previous=lines.join('\n');
  assert.equal(hash(previous),binding.beforeSha256,'complete pre-hand-gesture source recovered: '+path);
  return previous;
}
export function prepareHandGestureAimModuleRetirement(directory,{sourceRoot=process.cwd()}={}){
  assert.notEqual(resolve(directory),resolve(sourceRoot),'hand-gesture retirement requires a separate historical destination');
  const targets=[];
  for(const path of handGestureAimAddedPaths){
    const target=join(directory,path);
    if(!existsSync(target))continue;
    assert.equal(hash(normalize(readFileSync(target,'utf8'))),handGestureAimSourceLayer.files[path].afterSha256,'unreviewed hand-gesture added module destination: '+path);
    targets.push(target);
  }
  return ()=>{for(const target of targets)rmSync(target);};
}
