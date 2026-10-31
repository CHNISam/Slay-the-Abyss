import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('committed permanent card origins distinguish event, acquisition and combat copies',()=>{
 const r=runLua('tests/lua/card_upgrade_origins.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CARD_UPGRADE_ORIGINS_PASS 9/);
});
