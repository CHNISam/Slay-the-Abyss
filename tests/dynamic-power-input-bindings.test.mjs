import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('per-power input retains actor and power lifetime through failed and reentrant binding',()=>{
 const result=runLua('tests/lua/dynamic_power_input_bindings.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DYNAMIC_POWER_INPUT_PASS throw_sites=8 retire_sites=8/);
});
