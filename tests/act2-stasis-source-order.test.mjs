import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Stasis sorts real Silent Defect Watcher cards by complete original source metadata', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/act2_stasis_source_order.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ACT2_STASIS_SOURCE_ORDER_PASS 3/);
});
