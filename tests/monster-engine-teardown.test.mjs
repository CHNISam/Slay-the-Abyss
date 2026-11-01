import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('engine-owned monster teardown forgets native handles without setters or Destroy',()=>{
 const r=runLua('tests/lua/monster_engine_teardown.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/MONSTER_ENGINE_TEARDOWN_PASS/);
});
