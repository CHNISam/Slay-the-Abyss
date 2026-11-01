import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('shop relic source effects and selection contracts',()=>{
 const result=runLua('tests/lua/shop_relics_effects.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_SHOP_RELIC_EFFECTS_PASS 12/);
});
test('mandatory relic choices use live native node rows with stale gesture protection',()=>{
 const result=runLua('tests/lua/shop_relics_pending_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_SHOP_RELIC_PENDING_UI_PASS 9/);
});
test('shop relics acquired through Run expose real permanent reward and copy commands',()=>{
 const result=runLua('tests/lua/shop_relics_acquisition.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_SHOP_RELIC_ACQUISITION_PASS 8/);
});
