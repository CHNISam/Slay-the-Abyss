import test from 'node:test';import assert from 'node:assert/strict';import {runLua}from '../scripts/test-lua.mjs';
test('offline driver consumes visible mandatory relic tokens and preserves original room continuation',()=>{
 const r=runLua('tests/lua/m3_driver_relic_choices.lua');assert.equal(r.status,0,r.stderr||r.stdout);
 assert.match(r.stdout,/M3_DRIVER_RELIC_CHOICES_PASS 8/);
});
