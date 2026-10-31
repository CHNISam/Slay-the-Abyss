import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('offline driver respects public staged picker admission and operation-specific legal UIDs',()=>{
 const r=runLua('tests/lua/m3_driver_event_stage.lua');assert.equal(r.status,0,r.stderr||r.stdout);
 assert.match(r.stdout,/M3_DRIVER_EVENT_STAGE_PASS 7/);
});
