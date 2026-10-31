import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real deck details expose actual upgrade source and strike keyword read-only',()=>{
 const r=runLua('tests/lua/card_origin_ui.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CARD_ORIGIN_UI_PASS/);
});
