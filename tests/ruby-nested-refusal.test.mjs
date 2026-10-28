import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('ignored nested Recall refusals roll back gold/cards and original graph identities',()=>{
  const result=runLua('tests/fixtures/js-owned/tests/lua/ruby_nested_refusal.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/RUBY_NESTED_REFUSAL_PASS 3/);
});
