import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('A0 run score matches fixed static-reference arithmetic and rejects missing history', () => {
  const result = runLua('tests/lua/run_score_calculator.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /run_score_calculator: \d+ assertions passed/);
});
