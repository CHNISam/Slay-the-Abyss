import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('Nest uses public Nodes transactions and existing generated UI, including death and stale inputs',()=>{
 const result=runLua('tests/lua/nest_event_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NEST_EVENT_UI 5 passed/);
});
