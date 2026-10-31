import test from 'node:test';import assert from 'node:assert/strict';import {runLua}from '../scripts/test-lua.mjs';
test('offline driver resolves public choose_card candidates when actual event options have no picker metadata',()=>{
 const r=runLua('tests/lua/m3_driver_event_cards.lua');assert.equal(r.status,0,r.stderr||r.stdout);
 assert.match(r.stdout,/M3_DRIVER_EVENT_CARDS_PASS 3/);
});
