import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('two-act competition keeps same-run ownership, terminal choices, rollback and no persistent history', () => {
  const result = runLua('tests/lua/competition_two_act.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /COMPETITION_TWO_ACT_PASS 7; controlled boundaries; native\/natural NOT_RUN/);
});
