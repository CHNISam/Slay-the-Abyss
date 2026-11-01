import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('bounded M3 integration: Ruby refusal rolls back Darkstone health, floor48 exclusive choice, floor49 source fallback',()=>{
 const result=runLua('tests/lua/m3_v2_keys_darkstone.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/M3_V2_KEYS_DARKSTONE 3 passed/);
});
