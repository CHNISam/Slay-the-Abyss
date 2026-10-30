import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('real GameUI menu/character handoff retains one full background and releases before gameplay/disable',()=>{
 const r=runLua('tests/lua/support/official_background_flow.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/OFFICIAL_BACKGROUND_FLOW_PASS/);
});
test('real native entry keeps fallback interactive on template/create errors and retires callbacks on engine teardown',()=>{
 const r=runLua('tests/lua/support/official_background_errors.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/OFFICIAL_BACKGROUND_ERRORS_PASS/);
});
