import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('character selection allows exit confirmation and cancellation through actual UI buttons',()=>{
 const r=runLua('tests/lua/character_selection_exit.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/CHARACTER_SELECTION_EXIT_PASS/);
});
