import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Emerald map preserves legacy graphs and owns one source selection/entry boost across strict restore', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/emerald_map.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /EMERALD_MAP 6 groups; 0 failed; battle integration NOT_RUN/);
});
