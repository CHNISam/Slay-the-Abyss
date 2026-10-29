import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('relic controller Confirm suppresses only its same-frame native Click across paging close and bar',()=>{
  buildLuaData();buildUI();
  const result=runLua('tests/lua/relic_view_controller_click.lua');
  assert.equal(result.status,0,result.stderr+result.stdout);
  assert.match(result.stdout,/RELIC_CONTROLLER_CLICK_PASS/);
});
