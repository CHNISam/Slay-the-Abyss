import {projectArtPerfSource} from './art-perf-source-composition.mjs';
// Outer test-only layer: no historical witness, assertion or budget is changed.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/ready-art-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'e0987dbe3d3c835356bcdf57208d2d4cb7fa4d360d7ba463806e76c49d29e4df');
export const readyArtSourceLayer=JSON.parse(bytes);
export function preReadyArtSource(path,source){
 source=projectArtPerfSource(path,source,'art');
 const binding=readyArtSourceLayer.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 if(binding.beforeSha256===null)return null;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact ready-art hunk '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');assert.equal(hash(previous),binding.beforeSha256,'complete pre-ready-art source '+path);
 return previous;
}
export function prepareReadyArtRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'ready-art retirement requires a separate historical destination');
 const targets=[];
 for(const [path,binding] of Object.entries(readyArtSourceLayer.files)){
  if(binding.beforeSha256!==null)continue;
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(normalize(readFileSync(target,'utf8'))),binding.afterSha256,'unreviewed ready-art added module destination '+path);
  targets.push(target);
 }
 return ()=>{for(const target of targets)rmSync(target);};
}
