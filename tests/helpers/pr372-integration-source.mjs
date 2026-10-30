// Exact test-only projection of the reviewed combined slice. Runtime never imports this.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/pr372-integration-sources.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'2d4e9cbad0efc5f9df19963193a086cb497415ac9567ab066ef2ace65b3829c7','complete combined source identity');
export const integrationSources=JSON.parse(bytes).sources;
export function preIntegrationSource(path,source,target='base',{readSource=path=>readFileSync(path,'utf8')}={}){
 const binding=integrationSources[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!==binding.sha256||!Object.hasOwn(binding.targets,target))return source;
 for(const [linked,b] of Object.entries(integrationSources)){
  if(linked.startsWith('src/lua/')&&b.targets.base?.absent===true){
   const current=readSource(linked).replaceAll('\r\n','\n');
   assert.equal(hash(current),b.sha256,'unreviewed combined linked module: '+linked);
  }
 }
 const prior=binding.targets[target];
 if(prior.absent)return null;
 const lines=normalized.split('\n');
 for(const h of [...prior.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.current.length),h.current,'exact combined source hunk: '+path);
  lines.splice(h.at,h.current.length,...h.prior);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),prior.sha256,'complete target source: '+path);
 return previous;
}
export function prepareIntegrationRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'integration retirement requires separate destination');
 const targets=[];
 for(const [path,b] of Object.entries(integrationSources)){
  if(!path.startsWith('src/lua/')||b.targets.base?.absent!==true)continue;
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(readFileSync(target,'utf8').replaceAll('\r\n','\n')),b.sha256,'unreviewed integration module: '+path);targets.push(target);
 }
 return ()=>{for(const target of targets)if(existsSync(target))rmSync(target);};
}
