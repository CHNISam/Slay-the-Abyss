import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real GameUI and strict native controls wire Sphere and MindBloom through event battle and results',()=>{
 const result=runLua('tests/lua/event_combat_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/EVENT_COMBAT_UI_PASS 3 real host\/native controls/);
});
