import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('M3 map rejects horizontal drags on touch and mouse, including Up-only motion',()=>{
  buildLuaData(); buildUI();
  const result=runLua('tests/lua/m3_map_input_acceptance.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_M3_MAP_INPUT_ACCEPTANCE 4 passed; 0 failed/);
});

test('M3 held mobile card crosses aiming continuously and releases the previewed target once',()=>{
  const result=runLua('tests/lua/m3_touch_aim_trajectory.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/M3_TOUCH_AIM_TRAJECTORY_PASS/);
});

test('M3 touch and mouse recover missing map release after explicit termination without stale entry',()=>{
  const result=runLua('tests/lua/m3_map_terminal_recovery.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/M3_MAP_TERMINAL_RECOVERY 8 passed/);
});

for(const speed of ['fast','slow']) test(`M3 ${speed} touch cancellation repeats twenty times with tap fallback`,()=>{
  const result=runLua(`tests/lua/m3_touch_release_${speed}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/20 cancelled; C mode preserved/);
});

for(const speed of ['fast','slow']) test(`M3 ${speed} touch valid release submits twenty times without duplicate cost`,()=>{
  const result=runLua(`tests/lua/m3_touch_valid_${speed}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/20 submitted once/);
});
