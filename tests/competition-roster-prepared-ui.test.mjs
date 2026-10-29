import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('configured unavailable identities reject before direct/native/controller selection mutation or preview adaptation',()=>{
 const result=runLua('tests/lua/competition_roster_prepared_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/COMPETITION_PREPARED_UI_PASS 27; native\/natural NOT_RUN/);
});
