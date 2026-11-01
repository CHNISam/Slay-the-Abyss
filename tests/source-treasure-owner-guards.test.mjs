import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('source reward owner replacements and selected-row metatables refuse atomically; plain and legacy controls remain valid',()=>{
  const result=runLua('tests/lua/source_treasure_owner_guards.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/SOURCE_TREASURE_OWNER_GUARDS 4 passed/);
});
