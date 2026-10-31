import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('long potion effects clear title and actions, preserve copy and use configured bottle tints',()=>{
 const r=runLua('tests/lua/potion_popup_readability.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/POTION_POPUP_READABILITY_PASS/);
});
