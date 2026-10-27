import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('real Leader and Collector replacements retain visible actor identities and input ownership', () => {
  const result = runLua('tests/lua/summon_enemy_ui.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /SUMMON_ENEMY_UI 5 passed; 0 failed/);
});
