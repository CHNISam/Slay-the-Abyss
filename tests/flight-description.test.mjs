import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Flight wording identifies incoming attacks and matches normal versus fixed damage',()=>{
 const r=runLua('tests/lua/flight_description.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/FLIGHT_DESCRIPTION_PASS/);
});
