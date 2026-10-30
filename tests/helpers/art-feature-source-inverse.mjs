import {preIntegrationSource} from './pr372-integration-source.mjs';
// Test-only exact outer layer for the reviewed feature flags and fallback repair.
// Historical witnesses, source guards and performance budgets remain immutable.
import assert from 'node:assert/strict';
import {preRelicArtFeatureCompositionSource} from './relic-art-feature-composition.mjs';
import {createHash} from 'node:crypto';
import {existsSync,readFileSync,realpathSync,rmSync} from 'node:fs';
import {isAbsolute,join,relative,resolve,sep} from 'node:path';
import {fileURLToPath} from 'node:url';

const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const sourceDirectory=fileURLToPath(new URL('../..',import.meta.url));
const bytes=normalize(readFileSync(new URL('../fixtures/art-feature-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'b2bef34f482a5eca07b74a10d5ca31f04a5256a6b3a3d249ff8597a7b5962a30','complete art-feature/fallback outer source identity');
export const artFeatureSourceLayer=JSON.parse(bytes);
const legacyBytes=normalize(readFileSync(new URL('../fixtures/art-feature-source-layer-pre379.json',import.meta.url),'utf8'));
assert.equal(hash(legacyBytes),'33ad4cabfe6a3b678a7054f39975bca56e122ecc5ca2c3ad945392eb77b22afc','complete pre379 art-feature witness');
export const legacyArtFeatureSourceLayer=JSON.parse(legacyBytes);
const legacyLayer=legacyArtFeatureSourceLayer;
assert.equal(artFeatureSourceLayer.schemaVersion,1);
assert.equal(artFeatureSourceLayer.baseCommit,'1bfca6261044b92f8065bb83668c358b0a2627da');
assert.ok(Object.keys(artFeatureSourceLayer.files).length>0,'complete art-feature/fallback source inventory');
for(const [path,binding]of Object.entries(artFeatureSourceLayer.files)){
 assert.ok(path&&!isAbsolute(path)&&!path.includes('\\')&&!path.split('/').some(part=>!part||part==='.'||part==='..'),'relative art-feature source path');
 assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
 assert.ok(binding.beforeSha256===null||/^[a-f0-9]{64}$/.test(binding.beforeSha256));
 assert.ok(Array.isArray(binding.hunks));
 if(binding.beforeSha256===null)assert.deepEqual(binding.hunks,[],'genuinely new feature source has no historical source');
 let end=-1;
 for(const hunk of binding.hunks){
  assert.ok(Number.isInteger(hunk.at)&&hunk.at>=0&&hunk.at>=end,'ordered non-overlapping art-feature inverse hunks');
  assert.ok(Array.isArray(hunk.after)&&hunk.after.every(line=>typeof line==='string'));
  assert.ok(Array.isArray(hunk.before)&&hunk.before.every(line=>typeof line==='string'));
  end=hunk.at+hunk.after.length;
 }
}
export const artFeatureAddedPaths=Object.freeze(Object.entries(artFeatureSourceLayer.files)
 .filter(([,binding])=>binding.beforeSha256===null).map(([path])=>path));

export function preHistoricalArtFeatureSource(path,source,options={}){return preArtFeatureSource(path,source,{...options,history:true});}
export function preArtFeatureSource(path,source,{readSource=path=>readFileSync(path,'utf8'),history=false}={}){
 const integrationTarget=history?'base':'feature379';
 source=preRelicArtFeatureCompositionSource(path,preIntegrationSource(path,source,integrationTarget),'artFeature',{integrationTarget});
 const layer=history?legacyLayer:artFeatureSourceLayer;
 const binding=layer.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 // A recognized host cannot acquire old-source permission while its added
 // feature owner is absent or drifting. Baseline/unknown sources pass unchanged.
 for(const added of Object.keys(layer.files).filter(p=>layer.files[p].beforeSha256===null)){
  let actual;
  try{actual=readSource(added);}catch{assert.fail('unreviewed art-feature linked source missing: '+added);}
  assert.equal(typeof actual,'string','complete art-feature linked source: '+added);
  actual=preIntegrationSource(added,actual,integrationTarget);
  assert.equal(hash(normalize(actual)),layer.files[added].afterSha256,'unreviewed art-feature linked source drift: '+added);
 }
 if(binding.beforeSha256===null)return null;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact art-feature inverse hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.beforeSha256,'complete pre-art-feature source: '+path);
 return previous;
}

// Resolve aliases and destination parents before touching anything. Historical
// copies may live inside the checkout, but a copied path must never resolve to
// a live source file or escape its own destination (for example via a symlink).
function validateDestination(directory,sourceRoot){
 const destination=realpathSync(directory);
 const liveRoots=[sourceDirectory,sourceRoot].filter(existsSync).map(root=>realpathSync(root));
 for(const liveRoot of liveRoots)assert.notEqual(destination,liveRoot,'art-feature retirement requires a separate historical destination');
 for(const path of Object.keys(artFeatureSourceLayer.files)){
  const target=join(directory,path);if(!existsSync(target))continue;
  const actual=realpathSync(target),within=relative(destination,actual);
  assert.ok(within&&!isAbsolute(within)&&within!=='..'&&!within.startsWith('..'+sep),'art-feature retirement destination must not escape its historical copy: '+path);
  for(const liveRoot of liveRoots){
   const live=join(liveRoot,path);
   if(existsSync(live))assert.notEqual(actual,realpathSync(live),'art-feature retirement must never remove a live source: '+path);
  }
 }
 const targets=[];
 for(const path of artFeatureAddedPaths){
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(normalize(preIntegrationSource(path,readFileSync(target,'utf8'),'feature379'))),artFeatureSourceLayer.files[path].afterSha256,'unreviewed art-feature added module destination: '+path);
  targets.push(target);
 }
 return targets;
}
export function prepareArtFeatureRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'art-feature retirement requires a separate historical destination');
 validateDestination(directory,sourceRoot);
 // All present destinations validate before preparation returns, and again
 // before deletion so intervening unknown changes never acquire permission.
 return ()=>{for(const target of validateDestination(directory,sourceRoot))rmSync(target);};
}
