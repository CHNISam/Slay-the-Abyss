import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Sphere and MindBloom native fight callbacks retain physical event, generation, visibility and attachment owners',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/act3_event_ui_ownership.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT3_EVENT_UI_OWNERSHIP_PASS 10/);
});
