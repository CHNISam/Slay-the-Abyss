import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('deep_breath exact source result, upgraded boundaries and actual instance conservation',()=>{
 const r=runLua('tests/lua/colorless_five_deep_breath.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/COLORLESS_FIVE_PASS deep_breath/);
});
