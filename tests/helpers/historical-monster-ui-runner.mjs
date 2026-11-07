import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {readFileSync,writeFileSync,renameSync,statSync,unlinkSync,openSync,closeSync} from 'node:fs';
import {join,basename} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {luaTimeoutMs} from '../../scripts/ci-timeout-policy.mjs';
const phaseNames=new Set(['waiting-for-entry','entry','staged','projected','build-data','build-ui','built','lua','lua-finished','cleanup','complete']);
function readPhase(file,expected){
 assert.ok(statSync(file).size<=4096,'bounded historical phase receipt');
 const state=JSON.parse(readFileSync(file,'utf8'));
 assert.equal(state.schemaVersion,1);assert.equal(state.runId,expected.runId);assert.equal(state.script,expected.script);
 assert.ok(Number.isSafeInteger(state.startedAt)&&state.startedAt>0);
 if(expected.startedAt!==undefined)assert.equal(state.startedAt,expected.startedAt);
 assert.ok(phaseNames.has(state.phase)&&Number.isSafeInteger(state.elapsedMs)&&state.elapsedMs>=0);
 return state;
}
// Private per-call diagnostics only: never a replay result or permission cache.
export function recordHistoricalMonsterPhase(file,script,phase){
 if(file===undefined)return;
 assert.ok(phaseNames.has(phase),'known historical replay phase');
 const match=/^abyss-monster-phase-([a-f0-9-]{36})\.json$/.exec(basename(file));
 assert.ok(match,'private historical phase filename');
 const state=readPhase(file,{script,runId:match[1]});
 state.phase=phase;state.elapsedMs=Date.now()-state.startedAt;
 // Atomic replacement retains the last complete stage if this child is killed.
 writeFileSync(file+'.next',JSON.stringify(state));renameSync(file+'.next',file);
}
function phaseDescription(file,expected){
 try{const state=readPhase(file,expected);return `\nHistorical last phase: ${state.phase} (${state.elapsedMs} ms since this call started)`;}
 catch{return '\nHistorical last phase: unavailable (missing, unreadable or mismatched private receipt)';}
}
export function closeHistoricalMonsterRuntime(runtime,phase,succeeded,failure){
 let cleanupFailure;
 try{if(succeeded)phase('cleanup');}catch(error){cleanupFailure=error;}
 try{runtime.close();}catch(error){
  if(cleanupFailure)error.message+='\nHistorical phase diagnostic failed: '+cleanupFailure.message;
  cleanupFailure=error;
 }
 try{if(succeeded&&!cleanupFailure)phase('complete');}catch(error){cleanupFailure=error;}
 if(cleanupFailure){
  if(failure)failure.message+='\nHistorical replay cleanup failed: '+cleanupFailure.message;
  else throw cleanupFailure;
 }
}
export const historicalMonsterUiFixtures=Object.freeze([
 'tests/lua/battle_ui.lua',...Array.from({length:6},(_,i)=>`tests/lua/battle_ui_slice_${i+2}.lua`),
 'tests/lua/battle_ui_card_play.lua','tests/lua/battle_ui_card_play_slice_2.lua','tests/lua/battle_ui_card_play_slice_3.lua',
 'tests/lua/battle_ui_card_play_slice_4.lua',
 'tests/lua/battle_ui_card_play_slice_5.lua',
 'tests/lua/battle_ui_drag_click_compatibility.lua','tests/lua/battle_ui_drag_click_compatibility_slice_2.lua',
]);
export function runHistoricalMonsterUi(script,{timeout,cwd=process.cwd(),caseName,maxBuffer}={}){
 script=script.replaceAll('\\','/');
 assert.ok(historicalMonsterUiFixtures.includes(script)||script==='battle-refactor-render','only exact historical monster UI fixtures');
 assert.equal(caseName,undefined,'complete frozen cases and seeds must execute');
 timeout??=luaTimeoutMs.heavy;
 assert.ok(Number.isFinite(timeout)&&timeout>0,'positive original total deadline');
 const state={schemaVersion:1,runId:randomUUID(),script,startedAt:Date.now(),phase:'waiting-for-entry',elapsedMs:0};
 const phaseFile=join(tmpdir(),`abyss-monster-phase-${state.runId}.json`);
 let failure,owned=false;
 try{
 const fd=openSync(phaseFile,'wx');owned=true;
 try{writeFileSync(fd,JSON.stringify(state));}finally{closeSync(fd);}
 const result=spawnSync(process.execPath,[fileURLToPath(new URL('./historical-monster-ui-entry.mjs',import.meta.url)),script,String(timeout),phaseFile],{
  cwd,encoding:'utf8',timeout,maxBuffer:maxBuffer??(script==='battle-refactor-render'?64*1024*1024:1024*1024),windowsHide:true,
 });
 if(result.error){
  const output=[result.stdout?`\n--- Lua stdout ---\n${result.stdout}`:'',result.stderr?`\n--- Lua stderr ---\n${result.stderr}`:''].join('');
  throw new Error(`Lua runner failed (${script}, ${timeout} ms): ${result.error.message}${output}${phaseDescription(phaseFile,state)}`,{cause:result.error});
 }
 if(result.signal)throw new Error(`Lua runner terminated by ${result.signal}`);
 return result;
 }catch(error){failure=error;throw error;}
 finally{
  let cleanupFailure;
  if(owned)for(const file of [phaseFile+'.next',phaseFile])try{unlinkSync(file);}catch(error){if(error.code!=='ENOENT')cleanupFailure??=error;}
  if(cleanupFailure){if(failure)failure.message+='\nHistorical phase cleanup failed: '+cleanupFailure.message;else throw cleanupFailure;}
 }
}

// Bounded historical-only V8 heap; cases and original wall deadlines are unchanged.
export function historicalMonsterLuaArgs(cli,chunk){
 return ['--max-old-space-size=1024',cli,'-e',chunk];
}
