import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('source relic definitions obtain real effects and preserve camp restrictions',()=>{
 const r=runLua('tests/lua/relic_missing_definitions.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/LUA_MISSING_RELIC_DEFINITIONS_PASS 7/);
});
test('Ironclad, original-V4 Raiden and retained Defect can publicly claim seven source relics exactly once',()=>{
 const r=runLua('tests/lua/relic_missing_channels.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/LUA_MISSING_RELIC_CHANNELS_PASS 21/);
});
test('native camp buttons explain restrictions and retain a legal continue action',()=>{
 const r=runLua('tests/lua/relic_camp_ui.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/LUA_RELIC_CAMP_UI_PASS 3/);
});
