import {materializeBeforeM3Events,m3EventSourceLayer} from './m3-event-source-inverse.mjs';
// Historical source replay only. Runtime feature tests read production directly.
import assert from 'node:assert/strict';
import {preRelicRound2CompositionSource} from './relic-round2-composition.mjs';
import {preNativeEnemyThemeSource} from './native-enemy-theme-inverse.mjs';
import {existsSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=value=>value.replaceAll('\r\n','\n');
const hash=value=>value===null?null:createHash('sha256').update(normalize(value)).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/relic-completion-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'87baa37adcc1054e023966b4bda8f7d9ac0abb13e4c76a0b5f07a9020644e834','complete relic completion inverse witness');
export const relicCompletionInverse=JSON.parse(bytes);
assert.equal(relicCompletionInverse.schemaVersion,1);
assert.equal(relicCompletionInverse.baseCommit,'ce62e753065666fd26c9d85587a8f3ae2a580689');
const files=relicCompletionInverse.files;
assert.deepEqual(Object.keys(files),Object.keys(files).sort(),'canonical relic completion source inventory');
for(const [path,binding]of Object.entries(files)){
 assert.match(path,/^(?:src\/lua\/[^/]+\.lua|scripts\/[^/]+\.mjs|config\/[^/]+\.json|data\/.+\.json|tests\/lua\/sensory_stone_outcomes\.lua)$/);
 for(const key of ['beforeSha256','afterSha256'])assert.ok(binding[key]===null||/^[a-f0-9]{64}$/.test(binding[key]),'complete relic source identity: '+path);
 assert.notEqual(binding.beforeSha256,binding.afterSha256,'only changed relic completion sources: '+path);
 assert.ok(Array.isArray(binding.hunks));
 if(binding.beforeSha256===null||binding.afterSha256===null)assert.deepEqual(binding.hunks,[],'genuine file addition/removal only: '+path);
 let previousEnd=0;
 for(const hunk of binding.hunks){
  assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=previousEnd&&Number.isSafeInteger(hunk.beforeAt)&&hunk.beforeAt>=0,'exact ordered hunk positions: '+path);
  assert.ok(Array.isArray(hunk.before)&&Array.isArray(hunk.after));
  for(const line of [...hunk.before,...hunk.after])assert.ok(typeof line==='string'&&!line.includes('\n')&&!line.includes('\r'),'individual LF hunk line: '+path);
  previousEnd=hunk.at+hunk.after.length;
 }
}
export function requireRelicCompletionSource(path,source){
 source=preRelicRound2CompositionSource(path,source,'relic');
 source=preNativeEnemyThemeSource(path,source);
 const binding=files[path];
 assert.ok(binding,'unregistered relic completion source: '+path);
 assert.equal(source===null?null:typeof source,binding.afterSha256===null?null:'string','relic completion source must match existence: '+path);
 assert.equal(hash(source),binding.afterSha256,'unreviewed relic completion source: '+path);
 return binding;
}
export function tryRelicCompletionSource(path,source){
 source=preRelicRound2CompositionSource(path,source,'relic');
 source=preNativeEnemyThemeSource(path,source);
 const binding=files[path];
 // Undefined means not recognized. Null exclusively means genuine prior absence.
 if(!binding||hash(source)!==binding.afterSha256)return undefined;
 requireRelicCompletionSource(path,source);
 if(binding.beforeSha256===null)return null;
 assert.equal(typeof source,'string','inverse of a removed file requires explicit old source evidence');
 const lines=normalize(source).split('\n');
 // Both coordinates are zero-based LF-split lines, including the terminal
 // empty line. Reverse after-coordinates first, then verify before-coordinates.
 assert.equal(lines.length,binding.afterLines,'complete current line inventory: '+path);
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact relic inverse hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(lines.length,binding.beforeLines,'complete prior line inventory: '+path);
 assert.equal(hash(previous),binding.beforeSha256,'complete pre-relic source reconstructed: '+path);
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact prior hunk position: '+path);
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(hash(forward.join('\n')),binding.afterSha256,'exact forward relic source reconstruction: '+path);
 return previous;
}
export function preRelicCompletionSource(path,source){
 if(source!==null&&typeof source!=='string')return source;
 const previous=tryRelicCompletionSource(path,source);
 return previous===undefined?source:previous;
}
// Older archives only list their own changed files. Restore every exact
// pre-existing outer input before they materialize; retain genuine additions
// for their validated deferred retirement.
export function materializeBeforeRelicCompletionSources(directory){
 assert.notEqual(resolve(directory),resolve(process.cwd()),'historical sources require a separate destination');
 const outputs=[];
 for(const path of Object.keys(files).filter(path=>files[path].beforeSha256!==null)){
  const target=join(directory,path);if(!existsSync(target))continue;
  const source=readFileSync(target,'utf8');requireRelicCompletionSource(path,source);
  outputs.push([target,preRelicCompletionSource(path,source)]);
 }
 materializeBeforeM3Events(directory,{historicalPaths:Object.keys(files).filter(path=>m3EventSourceLayer.files[path]?.beforeSha256!=null)});
 for(const [target,source]of outputs){if(source===null)rmSync(target);else writeFileSync(target,source);}
}
export const relicCompletionAddedPaths=Object.freeze(Object.entries(files)
 .filter(([,binding])=>binding.beforeSha256===null).map(([path])=>path));
export function prepareRelicCompletionModuleRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'relic retirement requires separate historical destination');
 const targets=[];
 for(const path of relicCompletionAddedPaths){
  const target=join(directory,path);if(!existsSync(target))continue;
  requireRelicCompletionSource(path,readFileSync(target,'utf8'));targets.push(target);
 }
 return ()=>{for(const target of targets)rmSync(target);};
}
