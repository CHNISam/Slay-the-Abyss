import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {p0UiSourcePaths,p0UiSourceProof} from './helpers/p0-ui-source.mjs';
import {deckDeliveryPaths} from './helpers/deck-delivery-source-composition.mjs';
import {multiMonsterSourceLayer} from './helpers/multi-monster-art-source-inverse.mjs';
import {deliverySourceProof} from './helpers/delivery-source-composition.mjs';
import {historicalMonsterSourcePaths,verifiedHistoricalMonsterSources,materializeHistoricalMonsterUi} from './helpers/historical-monster-ui-materialize.mjs';
const read=p=>readFileSync(p,'utf8');
test('historical monster inventory includes every exact P0 owner and restores the matching exit layout',()=>{
 const prior=[...deckDeliveryPaths,...Object.keys(multiMonsterSourceLayer.files),...Object.keys(deliverySourceProof.targets.legacyMulti.files)];
 assert.deepEqual(historicalMonsterSourcePaths,[...new Set([...prior,...p0UiSourcePaths])].sort(),'only the existing inventory and exact P0 owners');
 for(const path of p0UiSourcePaths)assert.ok(historicalMonsterSourcePaths.includes(path),'missing historical P0 owner: '+path);
 const projected=new Map(verifiedHistoricalMonsterSources());
 const path='scripts/exit-ui-layout.mjs';
 assert.equal(createHash('sha256').update(projected.get(path)).digest('hex'),p0UiSourceProof.files[path].beforeSha256);
});
test('historical monster builders consume a coherent theme and exit layout',()=>{
 const directory=mkdtempSync(join(tmpdir(),'historical-monster-p0-'));
 try{
  materializeHistoricalMonsterUi(directory);
  const result=spawnSync(process.execPath,['--input-type=module','-e',"import{buildLuaData}from'./scripts/build-lua-data.mjs';import{buildUI}from'./scripts/build-ui.mjs';buildLuaData();buildUI();"],{cwd:directory,encoding:'utf8',timeout:60000});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('historical P0 projection rereads all current owners and rejects missing or drifting sources',()=>{
 verifiedHistoricalMonsterSources();
 for(const path of p0UiSourcePaths){
  for(const bad of [undefined,read(path)+'\n-- drift']){
   let calls=0;
   assert.throws(()=>verifiedHistoricalMonsterSources(process.cwd(),p=>p===path?(calls++,bad):read(p)),/unreviewed current historical monster closure/);
   assert.ok(calls>0,'fresh current owner read: '+path);
  }
 }
});
