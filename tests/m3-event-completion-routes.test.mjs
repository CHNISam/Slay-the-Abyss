import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('all 42 legal first-two-act identities have a source dispatcher',()=>{
  const result=runLua('tests/lua/original_event_dispatch.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/ORIGINAL_EVENT_DISPATCH_PASS 42 identities/);
});

test('11 newly completed events leave unique map exits through actual Nodes and Run commands',()=>{
  const result=runLua('tests/lua/m3_event_completion_routes.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/M3_EVENT_COMPLETION_ROUTES 12 passed/);
});
