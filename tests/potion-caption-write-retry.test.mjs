import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('potion caption cache retries rejected visibility and partial throwing text writes',()=>{
 const r=runLua('tests/lua/potion_caption_write_retry.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/POTION_CAPTION_WRITE_RETRY_PASS/);
});
