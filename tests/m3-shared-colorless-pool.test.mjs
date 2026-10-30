import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Match and Skull share the original act-wide colorless permutation and transactional owner',()=>{
 const r=runLua('tests/lua/m3_shared_colorless_pool.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/M3_SHARED_COLORLESS_POOL_PASS match_skull_match rollback act_reset/);
});
