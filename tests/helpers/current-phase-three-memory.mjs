// Fengari retains weak-key native controls. Isolate only this original 3/4
// slice; preparation and both VM startups share its unchanged 30-second budget.
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {currentPresentationNativePrelude} from './current-presentation-native.mjs';
export const currentPhaseThreeMemoryFixture='tests/lua/phase_three_presentation_slice_2.lua';
export const currentPhaseThreeMemoryGroups=Object.freeze([3,4]);
const sourcePath='tests/lua/phase_three_presentation.lua';
export const phaseThreeSourceSha256='9a99dc5dc1b7dc767f177b4f2f8d8726dee56833e46865c37a8bd874c4453515';
const variants=Object.freeze({3:184,4:204});
export function validatePhaseThreeMemoryGroups(groups){assert.deepEqual(groups,[3,4],'original groups3/4 exactly once in order');}
export function verifyPhaseThreeMemoryOutput(stdout,group){
 assert.deepEqual(stdout.split(/\r?\n/).filter(x=>x.startsWith('PHASE_THREE_CASE ')),[`PHASE_THREE_CASE ${group}`],'missing, duplicate, skipped or extra original case');
 assert.deepEqual(stdout.split(/\r?\n/).filter(x=>x.startsWith('PHASE_THREE_SLICE ')),[`PHASE_THREE_SLICE ${group} ${group} 1 ${variants[group]}`],'original complete variant receipt required');
 const role=group===3?'defect':'watcher';
 assert.deepEqual(stdout.split(/\r?\n/).filter(x=>x.startsWith('ok phase_three_presentation ')),[`ok phase_three_presentation 1 - ${role} every basic and upgrade reaches real BattleUI and DeckUI`],'original class identity required');
}
export function runCurrentPhaseThreeMemory(runLua,script,{timeout=30000,cwd=process.cwd(),caseName}={}){
 const deadline=performance.now()+timeout;
 assert.equal(script.replaceAll('\\','/'),currentPhaseThreeMemoryFixture,'only exact original slice2');
 assert.equal(caseName,undefined,'both complete original groups must execute');
 assert(Number.isFinite(timeout)&&timeout>0&&timeout<=30000,'original total30s deadline cannot be extended');
 validatePhaseThreeMemoryGroups(currentPhaseThreeMemoryGroups);
 const source=readFileSync(resolve(cwd,sourcePath),'utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(source).digest('hex'),phaseThreeSourceSha256,'entire frozen presentation body must remain intact');
 assert.equal(readFileSync(resolve(cwd,script),'utf8').replaceAll('\r\n','\n'),"assert(loadfile('tests/lua/phase_three_presentation.lua'))(3,4)\n",'original slice identity must remain intact');
 const native=currentPresentationNativePrelude(script,{cwd});assert(native,'explicit real native platform required');
 const remaining=()=>{const left=Math.floor(deadline-performance.now());assert(left>0,'phase3 original total deadline exhausted');return left;};
 const dir=mkdtempSync(join(tmpdir(),'abyss-phase3-memory-'));const out=[],errors=[];let last;
 try{
  for(const group of currentPhaseThreeMemoryGroups){
   const file=join(dir,`group-${group}.lua`);
   writeFileSync(file,native+`assert(loadfile(${luaString(resolve(cwd,sourcePath))}))(${group},${group})\n`);
   last=runLua(file,{cwd,timeout:remaining()});out.push(last.stdout??'');errors.push(last.stderr??'');remaining();
   if(last.status!==0)return {...last,stdout:out.join('\n'),stderr:errors.join('\n')};
   verifyPhaseThreeMemoryOutput(last.stdout,group);
  }
  return {...last,status:0,stdout:out.join('\n')+'\nPHASE_THREE_ORIGINAL_SLICE_PASS 3 4 2 388\n',stderr:errors.join('\n')};
 }finally{rmSync(dir,{recursive:true,force:true});}
}
