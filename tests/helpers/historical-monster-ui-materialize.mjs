import {prePostBetaRuntimeSource} from './post-beta-runtime-source.mjs';
import {verifiedHistoricalMonsterNodeClosure} from './historical-monster-node-closure.mjs';
import {preDeckDeliverySource,deckDeliveryPaths} from './deck-delivery-source-composition.mjs';
import {deliverySourceProof,preLegacyMultiSource,preLegacyUiSupportSource} from './delivery-source-composition.mjs';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync,mkdirSync,cpSync,symlinkSync,existsSync,constants} from 'node:fs';
import {join,dirname,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {multiMonsterSourceLayer,preMultiMonsterArtSource} from './multi-monster-art-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalized=s=>s.replaceAll('\r\n','\n');
const bytes=normalized(readFileSync(new URL('../fixtures/historical-monster-ui-support.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'f536f06de7bea3052a7303db34ec37cc68b631704f337ae3efba2d39515821ed','exact historical helper proof');
const support=JSON.parse(bytes);
assert.equal(support.baseCommit,multiMonsterSourceLayer.baseCommit);
assert.deepEqual(Object.keys(support.files),['tests/lua/support/game_ui_fixture.lua','tests/lua/support/battle_gesture_fixture.lua']);
export const historicalMonsterSourcePaths=Object.freeze([...new Set([...deckDeliveryPaths,...Object.keys(multiMonsterSourceLayer.files),...Object.keys(deliverySourceProof.targets.legacyMulti.files)])].sort());
export function verifiedHistoricalMonsterSources(sourceRoot=process.cwd(),read=path=>readFileSync(join(sourceRoot,path),'utf8')){
 const projected=[];
 try{
  for(const path of historicalMonsterSourcePaths){
   const live=normalized(preDeckDeliverySource(path,prePostBetaRuntimeSource(path,read(path),{readSource:read}),'delivery',{readSource:read})),outer=deliverySourceProof.targets.legacyMulti.files[path];
   if(outer)assert.equal(hash(live),outer.afterSha256,'unreviewed current monster source: '+path);
   const prior=preLegacyMultiSource(path,live,{readSource:read}),entry=multiMonsterSourceLayer.files[path];
   if(entry){assert.equal(hash(prior),entry.afterSha256,'unreviewed current monster UI source: '+path);const before=preMultiMonsterArtSource(path,prior,{readSource:read});assert.equal(before,entry.beforeSource);projected.push([path,before]);}
   else projected.push([path,prior]);
  }
  for(const [path,entry]of Object.entries(support.files)){
   const source=preLegacyUiSupportSource(path,read(path),{readSource:read});
   assert.equal(hash(normalized(source)),entry.afterSha256,'unreviewed current historical helper: '+path);
   assert.equal(hash(entry.beforeSource),entry.beforeSha256,'exact historical helper source: '+path);projected.push([path,entry.beforeSource]);
  }
 }catch(error){assert.fail('unreviewed current historical monster closure: '+error.message);}
 return projected;
}
export function materializeHistoricalMonsterUi(directory,sourceRoot=process.cwd(),{nodeClosure=false}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'historical projection must be isolated');
 // Verify the entire live layer and both helper closures before any writes.
 const projected=verifiedHistoricalMonsterSources(sourceRoot);
 if(nodeClosure)projected.push(...verifiedHistoricalMonsterNodeClosure(path=>readFileSync(join(sourceRoot,path),'utf8')));
 for(const input of ['src','data','scripts','tools','config','tests/lua','tests/helpers','tests/fixtures','package.json','package-lock.json','.release-please-manifest.json','CHANGELOG.md'])
  cpSync(join(sourceRoot,input),join(directory,input),{recursive:true});
 // Input-root provenance requires real isolated files, not aliases to source.
 cpSync(join(sourceRoot,'art'),join(directory,'art'),{recursive:true,dereference:true,mode:constants.COPYFILE_FICLONE});
 if(existsSync(join(sourceRoot,'node_modules')))symlinkSync(resolve(sourceRoot,'node_modules'),join(directory,'node_modules'),process.platform==='win32'?'junction':'dir');
 for(const [path,source]of projected){
  const target=join(directory,path);
  if(source===null)rmSync(target,{force:true});
  else{mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);}
 }
}
