import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
export const historicalMonsterUiFixtures=Object.freeze([
 'tests/lua/battle_ui.lua',...Array.from({length:6},(_,i)=>`tests/lua/battle_ui_slice_${i+2}.lua`),
 'tests/lua/battle_ui_card_play.lua','tests/lua/battle_ui_card_play_slice_2.lua','tests/lua/battle_ui_card_play_slice_3.lua',
 'tests/lua/battle_ui_drag_click_compatibility.lua','tests/lua/battle_ui_drag_click_compatibility_slice_2.lua',
 'tests/lua/card_input_port.lua','tests/lua/card_input_port_slice_2.lua','tests/lua/card_input_port_slice_3.lua',
]);
export function runHistoricalMonsterUi(script,{timeout,cwd=process.cwd(),caseName}={}){
 script=script.replaceAll('\\','/');
 assert.ok(historicalMonsterUiFixtures.includes(script)||script==='battle-refactor-render','only exact historical monster UI fixtures');
 assert.equal(caseName,undefined,'complete frozen cases and seeds must execute');
 timeout??=script==='battle-refactor-render'?120000:(script.includes('battle_ui_card_play')||script.includes('drag_click_compatibility')||script.includes('card_input_port'))?30000:60000;
 assert.ok(Number.isFinite(timeout)&&timeout>0,'positive original total deadline');
 const result=spawnSync(process.execPath,[fileURLToPath(new URL('./historical-monster-ui-entry.mjs',import.meta.url)),script,String(timeout)],{
  cwd,encoding:'utf8',timeout,maxBuffer:script==='battle-refactor-render'?64*1024*1024:1024*1024,windowsHide:true,
 });
 if(result.error){
  const output=[result.stdout?`\n--- Lua stdout ---\n${result.stdout}`:'',result.stderr?`\n--- Lua stderr ---\n${result.stderr}`:''].join('');
  throw new Error(`Lua runner failed (${script}, ${timeout} ms): ${result.error.message}${output}`,{cause:result.error});
 }
 if(result.signal)throw new Error(`Lua runner terminated by ${result.signal}`);
 return result;
}

// Bounded historical-only V8 heap; cases and original wall deadlines are unchanged.
export function historicalMonsterLuaArgs(cli,chunk){
 return ['--max-old-space-size=1024',cli,'-e',chunk];
}
