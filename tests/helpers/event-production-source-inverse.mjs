// Exact test-only outer layer for the production Duplicator and Match events.
// Current event tests load the live modules; only historical witnesses use this inverse.
import assert from 'node:assert/strict';
import {existsSync,readFileSync,writeFileSync,mkdirSync,rmSync} from 'node:fs';
import {join,dirname,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const gitBlob=source=>createHash('sha1').update(`blob ${Buffer.byteLength(source)}\0`).update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/event-production-source-inverse.json.gz',import.meta.url));
assert.equal(hash(bytes),'14c552023c7e838b54cd6e42bd66dc62ed264ca48ee7deb1c942bdaef1b489cd','complete production event source archive identity');
export const eventProductionInverse=JSON.parse(gunzipSync(bytes));
const proof=eventProductionInverse;
assert.equal(proof.schemaVersion,1);
assert.equal(proof.baseHead,'1dc33fe790a5f82be4f1bf2f0d09e339dcb943dd');
assert.equal(proof.baseTree,'b25f04658942be82ac9b5044ebf62e0862c0c2a5','actual complete Git1dc tree');
assert.ok(proof.files&&Object.keys(proof.files).length>0,'complete production event source inventory');
assert.deepEqual(Object.keys(proof.files),[...Object.keys(proof.files)].sort(),'canonical production event source inventory');
for(const [path,binding]of Object.entries(proof.files)){
 assert.ok(path&&!path.startsWith('/')&&!path.includes('\\')&&!path.split('/').some(part=>!part||part==='.'||part==='..'),'relative event production source path');
 assert.match(path,/^(?:src\/lua\/[^/]+\.lua|scripts\/[^/]+\.mjs|config\/[^/]+\.json|data\/release\/launch-content\.json)$/,'production/config/script inputs only');
 assert.equal(typeof binding.afterSource,'string','complete current event production source: '+path);
 assert.equal(binding.afterSource,normalize(binding.afterSource),'LF current event production archive source: '+path);
 assert.equal(hash(binding.afterSource),binding.afterSha256,'complete current event production source identity: '+path);
 assert.ok(binding.beforeSource===null||typeof binding.beforeSource==='string','complete Git1dc event production source: '+path);
 assert.equal(binding.beforeSource===null?null:hash(binding.beforeSource),binding.beforeSha256,'complete Git1dc source identity: '+path);
 assert.equal(binding.beforeSource===null?null:gitBlob(binding.beforeSource),binding.beforeGitBlob,'original Git1dc blob identity: '+path);
 assert.notEqual(binding.beforeSource,binding.afterSource,'only changed event production inputs: '+path);
}
export function requireEventProductionSource(path,source){
 const binding=proof.files[path];
 assert.ok(binding,'registered event production source: '+path);
 assert.equal(typeof source,'string','event production source must exist: '+path);
 assert.equal(hash(normalize(source)),binding.afterSha256,'unreviewed integrated event production source: '+path);
 return binding;
}
export function preEventProductionSource(path,source){
 const binding=proof.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 // Unknown/partial bytes remain exposed to each unchanged strict inner guard.
 if(hash(normalized)!==binding.afterSha256)return normalized;
 return binding.beforeSource;
}
export function materializeBeforeEventProduction(directory,{sourceRoot=process.cwd(),historicalPaths=[]}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'event production materialization requires a separate temporary historical destination');
 // The existing PR323/mobile/presentation materializers still own their final
 // exact outputs. This layer may neither overwrite nor delete their paths.
 const retained=new Set(historicalPaths);
 assert.equal(retained.size,historicalPaths.length,'unique historically owned event production paths');
 for(const path of retained)assert.ok(proof.files[path]&&proof.files[path].beforeSource!==null,'only pre-existing event production paths may retain their older exact owner: '+path);
 // Validate every live input, then every destination, before any writes/deletes.
 const sources=Object.entries(proof.files).map(([path,binding])=>{
  const live=join(sourceRoot,path);
  assert.ok(existsSync(live),'event production source must exist: '+path);
  requireEventProductionSource(path,readFileSync(live,'utf8'));
  return [path,binding];
 });
 for(const [path,binding]of sources){
  if(retained.has(path))continue;
  const target=join(directory,path);
  if(!existsSync(target))continue;
  const source=normalize(readFileSync(target,'utf8'));
  assert.ok(source===binding.afterSource||source===binding.beforeSource,'unreviewed event production destination: '+path);
 }
 for(const [path,binding]of sources){
  if(retained.has(path))continue;
  const target=join(directory,path);
  if(binding.beforeSource===null)rmSync(target,{force:true});
  else {mkdirSync(dirname(target),{recursive:true});writeFileSync(target,binding.beforeSource);}
 }
}
