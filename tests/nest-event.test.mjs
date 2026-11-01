import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Nest preserves source screens, NORMAL damage, fresh acquisition, permanent hooks and rollback', () => {
  const result = runLua('tests/lua/nest_event.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /NEST_EVENT 10 passed/);
});
