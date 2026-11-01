import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('current full-state comparator preserves scalar, deep, cyclic, alias and repeated-call diagnostics', () => {
  const result = runLua('tests/lua/current_game_ui_comparison.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /CURRENT_UI_COMPARATOR_PARITY_PASS cases=24/);
});
