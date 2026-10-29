import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preRosterConfigSource,projectRosterConfigSource,rosterConfigComposition as proof} from './helpers/competition-roster-config-composition.mjs';
import {preRosterSource,rosterSourceBindings} from './helpers/competition-roster-source-inverse.mjs';
import {preNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import {preIntegratedNodeUiSource} from './helpers/approved-node-ui-refactor.mjs';
import {preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';
import {preAcceptedPresentation} from './helpers/p0-presentation-inverse.mjs';
const path='config/architecture.json',read=p=>preAcceptedPr323Source(p,readFileSync(p,'utf8')).replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const project=(source,target)=>projectRosterConfigSource(path,source,target);
const source=read(path);
test('actual complete registration union adds only roster admission and retains every accepted Nodes Battle MaxHP classification',()=>{
 assert.equal(hash(source),'45bdb013ff452b410816bcd192f5ed5de9ecc0067a75b2a113721a03c98764ba');
 const current=project(source,'current'),roster=project(source,'roster');
 const acceptedRun=JSON.parse(read('tests/fixtures/run-max-hp-config-inverse.json'));
 assert.equal(hash(current),acceptedRun.combinedSha256LF);
 assert.equal(hash(roster),rosterSourceBindings.files[path].afterSha256);
 assert.equal(proof.targets.current.head,'e27c7a0f1060a61d995ab0b27d43cb23f1fbc07e');
 assert.equal(proof.targets.roster.head,'296bc0a290f7858f54a2d8b0cd1da052cee96a29');
 const live=JSON.parse(source),a=JSON.parse(current),b=JSON.parse(roster),union={...a.layers};
 for(const [name,layer]of Object.entries(b.layers)){
  if(Object.hasOwn(union,name))assert.equal(union[name],layer,'accepted source classification conflict: '+name);
  union[name]=layer;
 }
 assert.deepEqual(live.layers,union,'all actual registrations are the checked union, not a count or subset');
 assert.deepEqual({...live,layers:null},{...a,layers:null},'every non-registry architecture field remains');
 assert.deepEqual(Object.keys(live.layers),['abyss_run_admission',...Object.keys(a.layers)]);
 assert.equal(live.layers.abyss_run_admission,'core');
 const actual=JSON.parse(readFileSync(path,'utf8'));
 for(const file of readdirSync('src/lua',{recursive:true}).filter(file=>file.endsWith('.lua')))
  assert.ok(Object.hasOwn(actual.layers,file.slice(0,-4).replaceAll('/','.')),'actual source remains classified: '+file);
});
test('outer proof composes both immutable config witnesses through all existing historical guards',()=>{
 const current=project(source,'current'),roster=project(source,'roster');
 for(const target of ['current','roster']){
  const previous=project(source,target);
  assert.equal(project(source.replaceAll('\n','\r\n'),target),previous);
  assert.equal(preRosterConfigSource(path,source,target),previous);
  assert.equal(preRosterConfigSource(path,source.replaceAll('\n','\r\n'),target),previous);
  assert.equal(preRosterConfigSource(path,previous,target),previous);
 }
 assert.equal(preRosterSource(path,source),source,'old roster proof does not consume a new unowned union');
 assert.equal(preNodesBattleMaxHpConfig(path,source),source,'old triple proof stays strict');
 for(const historical of [current,roster])for(const guard of [preIntegratedNodeUiSource,preRetirementSource,preAcceptedPresentation])
  assert.equal(guard(path,source),guard(path,historical));
 assert.equal(hash(read('tests/fixtures/competition-roster-source-inverse.json')),'cb5cfb72ee26b567d534333d685d38d5c72aca79b9a148fd63ec625f87399fcc');
 assert.equal(hash(read('tests/fixtures/nodes-battle-max-hp-config-inverse.json')),'5e130a11180cb03714f315a21f5cf90a722374c2833dda033529851ad2809b92');
});
test('all actual registration mutations reject unknown identities while retaining the exact complete prior config witness',()=>{
 const layers=JSON.parse(source).layers;
 const previous=project(source,'current');
 let mutations=0,accepted=0;
 for(const [name,layer]of Object.entries(layers)){
  const line=source.split('\n').find(row=>row.includes(`"${name}":`));assert.ok(line);
  for(const mutant of [source.replace(line+'\n',''),source.replace(line+'\n',line+'\n'+line+'\n'),
   source.replace(`"${name}":`,`"${name}_unreviewed":`),source.replace(line,line.replace(`"${layer}"`,`"${layer==='core'?'ui':'core'}"`))]){
   assert.notEqual(mutant,source);mutations++;
   for(const target of ['current','roster']){
    assert.throws(()=>project(mutant,target),/unreviewed integrated roster config source/);
    assert.equal(preRosterConfigSource(path,mutant,target),mutant);
   }
   if(mutant===previous){
    accepted++;
    for(const guard of [preIntegratedNodeUiSource,preRetirementSource,preAcceptedPresentation])
     assert.equal(guard(path,mutant),guard(path,previous),'the exact full prior config remains a valid historical witness');
   }else for(const guard of [preIntegratedNodeUiSource,preRetirementSource,preAcceptedPresentation])
     assert.throws(()=>guard(path,mutant),/unreviewed integrated/);
  }
 }
 assert.equal(mutations,Object.keys(layers).length*4);
 assert.equal(accepted,1,'only removing the sole admission insertion recovers a complete old config');
});
test('config reordering unrelated bytes and missing wrong-path or target inputs remain rejected',()=>{
 const first='    "abyss_run_admission": "core",\n',next='    "abyss_run_potion_candidate": "core",\n';
 for(const mutant of [source+'\n',source.replace(first+next,next+first),source.replace('"dynamicExceptions": []','"dynamicExceptions": ["unknown"]'),source.replace('"reason": "Potion/upgrade/HP','"reason": "unreviewed Potion/upgrade/HP')]){
  assert.notEqual(mutant,source);
  for(const target of ['current','roster'])assert.throws(()=>project(mutant,target),/unreviewed integrated roster config source/);
  assert.throws(()=>preIntegratedNodeUiSource(path,mutant),/unreviewed integrated/);
 }
 for(const missing of [null,undefined,''])assert.throws(()=>project(missing,'current'),/roster config/);
 assert.throws(()=>project(source,'unknown'),/roster config composition target/);
 assert.throws(()=>projectRosterConfigSource('wrong.json',source,'current'),/roster config composition path/);
 assert.equal(preRosterConfigSource('wrong.json',source),source);
});
