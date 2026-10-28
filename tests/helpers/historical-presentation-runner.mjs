import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

// One complete historical fixture, still executed in Fengari. Preparation and
// Lua share its original 30s total budget. It never certifies the live UI.
export function runHistoricalPresentation(_run,script,{timeout=30000,cwd,caseName}={}){
  assert.equal(script.replaceAll('\\','/'),'tests/lua/presentation_responsibilities_trace.lua');
  assert.equal(caseName,undefined,'the complete historical scenario must execute');
  const entry=fileURLToPath(new URL('./historical-presentation-entry.mjs',import.meta.url));
  const result=spawnSync(process.execPath,[entry,script,String(timeout)],{
    cwd,encoding:'utf8',timeout,maxBuffer:1024*1024,windowsHide:true,
  });
  if(result.error)throw new Error('Historical Lua replay failed within its original total deadline: '+result.error.message,{cause:result.error});
  return result;
}
