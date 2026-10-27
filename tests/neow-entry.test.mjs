import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const [file,marker,count]of [['neow_history.lua','NEOW_HISTORY',4],['neow_entry_ui.lua','NEOW_ENTRY_UI',8],
 ['neow_game_ui.lua','NEOW_GAME_UI',5],['source_treasure_token.lua','SOURCE_TREASURE_TOKEN',6]]){
 test(`Neow normal entry and session history: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`${marker} ${count} passed`));
 });
}
