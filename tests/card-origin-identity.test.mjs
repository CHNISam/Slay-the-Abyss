import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Astrolabe public selection names its real source for all three replacement UIDs',()=>{
 const r=runLua('tests/lua/astrolabe_upgrade_origin.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ASTROLABE_UPGRADE_ORIGIN_PASS 3/);
});
test('upgrade origins reject stale identity and state while retaining fresh explicit records',()=>{
 const r=runLua('tests/lua/card_origin_identity.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CARD_ORIGIN_IDENTITY_PASS 12/);
});
