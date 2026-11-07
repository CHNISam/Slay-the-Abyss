import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {luaTimeoutMs} from '../../scripts/ci-timeout-policy.mjs';

export const historicalSapphireFixtures=Object.freeze([
  'tests/lua/sapphire_treasure.lua',
  'tests/lua/sapphire_treasure_slice_2.lua',
  'tests/lua/sapphire_treasure_slice_3.lua',
  'tests/lua/sapphire_treasure_slice_4.lua',
  'tests/lua/sapphire_treasure_slice_5.lua',
]);
export const historicalPresentationFixtures=Object.freeze([
  'tests/lua/presentation_responsibilities_trace.lua',
  'tests/lua/presentation_responsibilities_text.lua',
  ...historicalSapphireFixtures,
]);

// Complete historical fixtures, still executed in Fengari. Preparation and
// Lua share the central execution guard. It never certifies the live UI.
export function runHistoricalPresentation(_run,script,{timeout=luaTimeoutMs.default,cwd,caseName,maxBuffer=1024*1024}={}){
  script=script.replaceAll('\\','/');
  assert.ok(historicalPresentationFixtures.includes(script),'only exact historical presentation fixtures');
  assert.equal(caseName,undefined,'the complete historical scenario must execute');
  const entry=fileURLToPath(new URL(historicalSapphireFixtures.includes(script)
    ? './historical-sapphire-entry.mjs' : './historical-presentation-entry.mjs',import.meta.url));
  const result=spawnSync(process.execPath,[entry,script,String(timeout)],{
    cwd,encoding:'utf8',timeout,maxBuffer,windowsHide:true,
  });
  if(result.error){
    // The outer deadline can expire before the inner Lua runner returns.
    // Retain completed preparation phases and any child diagnostics without
    // retrying, changing its original deadline, or converting failure to pass.
    const output=[
      result.stdout?`\n--- Historical replay stdout ---\n${result.stdout}`:'',
      result.stderr?`\n--- Historical replay stderr ---\n${result.stderr}`:'',
    ].join('');
    throw new Error('Historical Lua replay failed within its original total deadline: '+result.error.message+output,{cause:result.error});
  }
  return result;
}
