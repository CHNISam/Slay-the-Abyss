import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('deck detail taps do not consume native scroll drag or its release click',()=>{
 const r=runLua('tests/lua/deck_scroll_detail.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/DECK_SCROLL_DETAIL_PASS/);
});
