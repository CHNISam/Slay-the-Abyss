import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preRosterConfigSource,projectRosterConfigSource,rosterConfigComposition as proof} from './competition-roster-config-composition.mjs';
import {preRosterSource,rosterSourceBindings} from './competition-roster-source-inverse.mjs';
import {preNodesBattleMaxHpConfig} from './nodes-battle-max-hp-config-inverse.mjs';
import {preIntegratedNodeUiSource} from './approved-node-ui-refactor.mjs';
import {preRetirementSource} from './presentation-announcement-retirement.mjs';
import {preAcceptedPresentation} from './p0-presentation-inverse.mjs';
const path='config/architecture.json',read=p=>preAcceptedPr323Source(p,readFileSync(p,'utf8')).replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const project=(source,target)=>projectRosterConfigSource(path,source,target);
const source=read(path);

export const rosterMutationEntries=Object.freeze(Object.entries(JSON.parse(source).layers).map(Object.freeze));
export const rosterMutationKinds=Object.freeze(['remove','duplicate','rename','reclassify']);
export const rosterMutationCases=Object.freeze(rosterMutationEntries.flatMap(([name],index)=>rosterMutationKinds.map(kind=>Object.freeze({id:name+'\0'+kind,index,name,kind}))));
export function selectRosterMutationEntries(partition){
 assert.ok(Number.isInteger(partition)&&partition>=1&&partition<=4,'exact roster partition 1..4');
 return rosterMutationEntries.filter((_,index)=>index%4===partition-1);
}
export function runRosterMutationPartition(partition){
 const selectedEntries=selectRosterMutationEntries(partition);
 const expectedAccepted=selectedEntries.some(([name])=>name==='abyss_run_admission')?1:0;
 // BEGIN EXACT ORIGINAL MUTATION BODY

 const layers=JSON.parse(source).layers;
 const previous=project(source,'current');
 let mutations=0,accepted=0;
 for(const [name,layer]of selectedEntries){
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
 assert.equal(mutations,selectedEntries.length*4);
 assert.equal(accepted,expectedAccepted,'only removing the sole admission insertion recovers a complete old config');
 // END EXACT ORIGINAL MUTATION BODY
 return {mutations,accepted};
}
