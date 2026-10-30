import {projectArtPerfSource} from './art-perf-source-composition.mjs';
import {preNativeMonsterArtSource} from './native-monster-art-source-inverse.mjs';
// Test-only exact outer layer for the reviewed round-two presentation extraction.
// Old witnesses keep their full bytes; unknown edits remain visible to their guards.
import assert from 'node:assert/strict';
import {preRelicRound2CompositionSource} from './relic-round2-composition.mjs';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('./round2-ui-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'3ee6197fd8128898520bce5d3d002d8f384c140a52ede3557d3af0f89ff4b7e9','complete round-two UI outer source identity');
export const round2UiSourceLayer=JSON.parse(bytes);
assert.equal(round2UiSourceLayer.schemaVersion,1);
assert.equal(round2UiSourceLayer.baseCommit,'a7b03825b74cd6555efc3cf4c8dc7abacd114611');
export const round2UiAddedPaths=Object.freeze([
  'src/lua/abyss_feedback_actor_painter.lua','src/lua/abyss_game_ui_menu_view.lua',
]);
assert.deepEqual(Object.keys(round2UiSourceLayer.files),[
  'config/architecture.json','src/lua/abyss_feedback.lua','src/lua/abyss_game_ui.lua',...round2UiAddedPaths,
]);
for(const [path,binding]of Object.entries(round2UiSourceLayer.files)){
  assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
  assert.ok(binding.beforeSha256===null||/^[a-f0-9]{64}$/.test(binding.beforeSha256));
  assert.equal(binding.beforeSha256===null,round2UiAddedPaths.includes(path),'only the two new responsibilities have no historical source');
  assert.ok(Array.isArray(binding.hunks));
  if(binding.beforeSha256===null)assert.deepEqual(binding.hunks,[]);
}
export function preRound2UiSource(path,source,{readSource=path=>projectArtPerfSource(path,readFileSync(path,'utf8'),'perf')}={}){
  source=projectArtPerfSource(path,preNativeMonsterArtSource(path,source),'perf');
  const binding=round2UiSourceLayer.files[path];
  if(binding)source=preRelicRound2CompositionSource(path,source,'round2');
  if(!binding||typeof source!=='string')return source;
  const normalized=normalize(source);
  if(hash(normalized)!==binding.afterSha256)return source;
  // Every recognized current host/config binds both actual extracted modules.
  // No current host gains historical permission if either responsibility drifts.
  for(const added of round2UiAddedPaths){
    let actual;
    try{actual=readSource(added);}catch{assert.fail('unreviewed round-two UI linked module missing: '+added);}
    assert.equal(typeof actual,'string','complete round-two UI linked source: '+added);
    actual=preNativeMonsterArtSource(added,actual);
    assert.equal(hash(normalize(actual)),round2UiSourceLayer.files[added].afterSha256,
      'unreviewed round-two UI linked module drift: '+added);
  }
  if(binding.beforeSha256===null)return null;
  const lines=normalized.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact round-two UI inverse hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const previous=lines.join('\n');
  assert.equal(hash(previous),binding.beforeSha256,'complete pre-round-two UI source recovered: '+path);
  return previous;
}

// Validate the entire copied module inventory before returning any deletion.
// This is only used by the existing historical materializer, never the live tree.
export function prepareRound2UiModuleRetirement(directory,{sourceRoot=process.cwd()}={}){
  assert.notEqual(resolve(directory),resolve(sourceRoot),'round-two UI retirement requires a separate historical destination');
  const targets=[];
  for(const path of round2UiAddedPaths){
    const target=join(directory,path);
    if(!existsSync(target))continue;
    assert.equal(hash(normalize(projectArtPerfSource(path,readFileSync(target,'utf8'),'perf'))),round2UiSourceLayer.files[path].afterSha256,
      'unreviewed round-two UI added module destination: '+path);
    targets.push(target);
  }
  return ()=>{for(const target of targets)rmSync(target);};
}
