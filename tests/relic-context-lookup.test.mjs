import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('source relic eligibility retains deck order and current definitions with bounded catalogue reads',()=>{
  const result=runLua('tests/lua/relic_context_lookup.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/RELIC_CONTEXT_LOOKUP_PASS/);
});
