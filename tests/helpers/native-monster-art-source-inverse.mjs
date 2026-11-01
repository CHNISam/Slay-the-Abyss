import {preIntegrationSource} from './pr372-integration-source.mjs';
import {architectureSourceFormat} from './architecture-source-format.mjs';
// Test-only exact outer inverse. Production GameUI tests use the actual drawing.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/native-monster-art-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'055c8877bcc2632e7fb992acd7043049e4c218f1695f42361db6977e79ffdcaf','complete native monster outer source identity');
export const nativeMonsterSourceLayer=JSON.parse(bytes);
assert.equal(nativeMonsterSourceLayer.schemaVersion,1);
assert.equal(nativeMonsterSourceLayer.baseCommit,'1fcd321ca9d6f79b4e5bbdfede48069119f5ed52');
for(const [path,binding]of Object.entries(nativeMonsterSourceLayer.files)) {
 assert.match(path,/^(?:src\/lua\/[^/]+\.lua|scripts\/[^/]+\.mjs|scripts\/art\/assemble-native-card-samples\.py|config\/architecture\.json|data\/presentation\/native-monster-art\.json)$/);
 assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
 assert.ok(binding.beforeSha256===null||/^[a-f0-9]{64}$/.test(binding.beforeSha256));
 if(binding.beforeSha256===null)assert.deepEqual(binding.hunks,[]);
}
export function preNativeMonsterArtSource(path,source,{readSource=path=>readFileSync(path,'utf8')}={}) {
 try{source=preIntegrationSource(path,source,'monster',{readSource});}catch(error){assert.fail('native monster linked source missing or invalid: '+error.message);}
 const binding=nativeMonsterSourceLayer.files[path];
 if(!binding||typeof source!=='string')return source;
 let text=normalize(source);
 // Inherit the existing architecture-only whitespace permission. Token identity
 // still rejects duplicate keys, string escapes, unknown values and extra bytes.
 if(path==='config/architecture.json')try {
  const {formatted,tokensEqual}=architectureSourceFormat(path,text);
  if(tokensEqual&&hash(formatted)===binding.afterSha256)text=formatted;
 }catch{ /* Unrecognized source must remain exposed to strict older guards. */ }
 if(hash(text)!==binding.afterSha256)return source;
 // Recognized outer hosts must bind live added owners on every call. Never memoize these reads.
 for(const added of nativeMonsterAddedPaths) {
  let actual;try{actual=preIntegrationSource(added,readSource(added),'monster',{readSource});}catch{assert.fail('native monster linked source missing: '+added);}
  assert.equal(typeof actual,'string','native monster linked source must exist: '+added);
  assert.equal(hash(normalize(actual)),nativeMonsterSourceLayer.files[added].afterSha256,'native monster linked source identity: '+added);
 }

 if(binding.beforeSha256===null)return null;
 const lines=text.split('\n');
 for(const hunk of [...binding.hunks].reverse()) {
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact native monster inverse hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.beforeSha256,'complete prior source recovered: '+path);
 return previous;
}
export const nativeMonsterAddedPaths=Object.freeze(Object.entries(nativeMonsterSourceLayer.files)
 .filter(([,binding])=>binding.beforeSha256===null).map(([path])=>path));
export function prepareNativeMonsterRetirement(directory,{sourceRoot=process.cwd()}={}) {
 assert.notEqual(resolve(directory),resolve(sourceRoot),'native monster retirement requires a separate historical destination');
 const targets=[];
 for(const path of nativeMonsterAddedPaths) {
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(normalize(preIntegrationSource(path,readFileSync(target,'utf8'),'monster'))),nativeMonsterSourceLayer.files[path].afterSha256,'unreviewed native monster added module destination: '+path);
  targets.push(target);
 }
 return ()=>{for(const target of targets)rmSync(target);};
}
