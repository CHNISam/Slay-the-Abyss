import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runCurrentPhaseThreeMemory as run,currentPhaseThreeMemoryFixture as fixture,validatePhaseThreeMemoryGroups as plan,verifyPhaseThreeMemoryOutput as verify} from './helpers/current-phase-three-memory.mjs';
const receipt=g=>`ok phase_three_presentation 1 - ${g===3?'defect':'watcher'} every basic and upgrade reaches real BattleUI and DeckUI\nPHASE_THREE_CASE ${g}\nPHASE_THREE_SLICE ${g} ${g} 1 ${g===3?184:204}\n`;
test('only the original groups3/4 execute once in order with unchanged complete variant receipts',()=>{
 plan([3,4]);for(const bad of [[3],[4],[4,3],[3,3,4],[3,4,4],[],[3,5]])assert.throws(()=>plan(bad));
 for(const g of [3,4]){const good=receipt(g);verify(good,g);for(const bad of ['',receipt(g===3?4:3),good+good,good.replace(`PHASE_THREE_CASE ${g}`,`PHASE_THREE_CASE ${g===3?4:3}`),good.replace(g===3?'184':'204','2'),good.replace(g===3?'defect':'watcher','another')])assert.throws(()=>verify(bad,g));}
});
test('real wrapper preserves full original source and runs both startups under one decreasing30s deadline',()=>{
 let calls=0,last=30001;
 const r=run((file,opts)=>{const g=[3,4][calls++];const text=readFileSync(file,'utf8');assert(text.includes(`(${g},${g})`));assert(text.includes('F.withMonsterActors(platform)'));assert(opts.timeout>0&&opts.timeout<=last);last=opts.timeout;return{status:0,signal:null,stdout:receipt(g),stderr:''};},fixture);
 assert.equal(calls,2);assert.match(r.stdout,/PHASE_THREE_ORIGINAL_SLICE_PASS 3 4 2 388/);
 assert.equal((r.stdout.match(/^PHASE_THREE_CASE /gm)||[]).length,2);
});
test('missing, duplicate or skipped child output and a child failure cannot certify the original slice',()=>{
 for(const bad of ['',receipt(4),receipt(3)+receipt(3)])assert.throws(()=>run(()=>({status:0,stdout:bad,stderr:''}),fixture));
 const r=run(()=>({status:1,stdout:receipt(3),stderr:'deliberate child failure'}),fixture);assert.equal(r.status,1);assert.doesNotMatch(r.stdout,/ORIGINAL_SLICE_PASS/);
 assert.throws(()=>run(()=>{throw Error('deliberate original signal');},fixture),/deliberate original signal/);
});
test('preparation and both children share the original budget, with no per-child reset or extension',t=>{
 // Advance only the monotonic clock: real preparation, deadline checks and
 // receipt validation still run, without assuming OS sleeps wake on time.
 for(const {timeout,preparation,childDuration,expectedTimeouts,exhausted} of [
  {timeout:10,preparation:11,childDuration:20,expectedTimeouts:[],exhausted:true},
  {timeout:10,preparation:0,childDuration:20,expectedTimeouts:[10],exhausted:true},
  {timeout:35,preparation:5,childDuration:20,expectedTimeouts:[30,10],exhausted:true},
  {timeout:35,preparation:5,childDuration:10,expectedTimeouts:[30,20],exhausted:false},
 ]){
  let started=false,elapsed=0;const childTimeouts=[];
  const clock=t.mock.method(performance,'now',()=>{
   if(!started){started=true;return 0;}
   return preparation+elapsed;
  });
  try{
   const execute=()=>run((file,opts)=>{
    const group=[3,4][childTimeouts.length];childTimeouts.push(opts.timeout);
    elapsed+=childDuration;return{status:0,stdout:receipt(group),stderr:''};
   },fixture,{timeout});
   if(exhausted)assert.throws(execute,/total deadline exhausted/);
   else assert.match(execute().stdout,/PHASE_THREE_ORIGINAL_SLICE_PASS 3 4 2 388/);
   assert.deepEqual(childTimeouts,expectedTimeouts,'preparation and prior children consume the same original budget');
  }finally{clock.mock.restore();}
 }
 for(const timeout of [0,-1,30001,Infinity])assert.throws(()=>run(()=>{},fixture,{timeout}),/deadline cannot be extended/);
 assert.throws(()=>run(()=>{},fixture,{caseName:'defect'}),/both complete original groups/);
 for(const path of [fixture+'.other','tests/lua/phase_three_presentation.lua','tests/lua/phase_three_presentation_slice_3.lua'])assert.throws(()=>run(()=>{},path),/only exact/);
});
test('original fullsource hash and exact slice file reject drift before executing any child',()=>{
 const dir=mkdtempSync(join(tmpdir(),'phase3-source-negative-'));
 try{
  mkdirSync(join(dir,'tests/lua'),{recursive:true});const source='tests/lua/phase_three_presentation.lua';
  writeFileSync(join(dir,source),readFileSync(source,'utf8')+'\n-- unauthorized\n');writeFileSync(join(dir,fixture),readFileSync(fixture,'utf8'));
  assert.throws(()=>run(()=>{throw Error('child must not run');},fixture,{cwd:dir}),/entire frozen presentation body/);
  writeFileSync(join(dir,source),readFileSync(source,'utf8'));writeFileSync(join(dir,fixture),readFileSync(fixture,'utf8').replace('(3,4)','(3,3)'));
  assert.throws(()=>run(()=>{throw Error('child must not run');},fixture,{cwd:dir}),/original slice identity/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
