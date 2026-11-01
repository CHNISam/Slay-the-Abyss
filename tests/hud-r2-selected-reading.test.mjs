import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Host raises first/middle/last reading cards above neighbours within safe canvas at owner widths',()=>{
 const r=runLua('tests/lua/hud_r2_selected_reading.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/HUD_R2_READING_PASS/);
});
