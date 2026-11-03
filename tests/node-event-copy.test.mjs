import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('node and event copy callers depend on the pure owner and preserve detached graphs',()=>{
  const result=runLua('tests/lua/node_event_copy.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NODE_EVENT_COPY_PASS 3 direct owners/);
});
