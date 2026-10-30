import {preReadyArtSource,prepareReadyArtRetirement} from './ready-art-source-inverse.mjs';
// Outer test-only layer: no historical witness, assertion or budget is changed.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/official-background-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'db49c03e83dfb42f9d21fdda43a99af86d3be3c8bbd7352c7f4134225192dc07');
export const backgroundSourceLayer=JSON.parse(bytes);
export function preBackgroundSource(path,source){
 source=preReadyArtSource(path,source);
 const binding=backgroundSourceLayer.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 if(binding.beforeSha256===null)return null;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact background hunk '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');assert.equal(hash(previous),binding.beforeSha256,'complete pre-background source '+path);
 return previous;
}
export function prepareBackgroundRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'background retirement requires a separate historical destination');
 const retireReady=prepareReadyArtRetirement(directory,{sourceRoot});
 const targets=[];
 for(const [path,binding] of Object.entries(backgroundSourceLayer.files)){
  if(binding.beforeSha256!==null)continue;
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(preReadyArtSource(path,normalize(readFileSync(target,'utf8')))),binding.afterSha256,'unreviewed background added module destination '+path);
  targets.push(target);
 }
 return ()=>{retireReady();for(const target of targets)rmSync(target);};
}
