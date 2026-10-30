import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

import {launchBaselineFixture,loadLaunchBaselineValidator} from './helpers/launch-baseline-fixture.mjs';
const root=launchBaselineFixture();
const {validateLaunchContent:validateCurrentLaunchContent}=await loadLaunchBaselineValidator(root);
const validateLaunchContent=(manifest,options={})=>validateCurrentLaunchContent(manifest,{...options,root});
const fresh=()=>JSON.parse(readFileSync(resolve(root,'data/release/launch-content.json'),'utf8'));
test('louse pool union retains both color channels without fixed enemies',()=>{
 const manifest=fresh();assert.deepEqual(validateLaunchContent(manifest,{runtime:false}),[]);
 for(const [id,n] of [['louse_pair',2],['louse_trio',3]]){
  const e=manifest.legacyData.encounters.find(e=>e.id===id);assert.deepEqual(e.lousePool,['red_louse','green_louse']);assert.equal(e.louseCount,n);assert.equal(Object.hasOwn(e,'enemies'),false);
 }
});
for(const id of ['louse_pair','louse_trio']) for(const [name,change,field] of [
 ['missing pool',e=>delete e.lousePool,'lousePool'],['reversed pool',e=>e.lousePool.reverse(),'lousePool'],
 ['duplicate color',e=>e.lousePool[1]='red_louse','lousePool'],['missing count',e=>delete e.louseCount,'louseCount'],
 ['wrong count',e=>e.louseCount=4,'louseCount'],['stale fixed list',e=>e.enemies=['red_louse','green_louse'],'enemies'],
])test(id+' inventory rejects '+name,()=>{
 const m=fresh();change(m.legacyData.encounters.find(e=>e.id===id));assert.ok(validateLaunchContent(m,{runtime:false}).some(e=>e.includes(`encounters/${id}/${field}`)));
});
for(const id of ['red_louse','green_louse'])test(id+' inventory rejects a lost eligible encounter channel',()=>{
 const m=fresh();m.enemies.find(e=>e.id===id).channels=['encounter:louse_pair'];
 assert.ok(validateLaunchContent(m,{runtime:false}).some(e=>e.includes(`enemies/${id} channels`)));
});
