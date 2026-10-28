import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('new Boss intents and mixed split actors work in generated battle controls', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/bosses_intent_ui.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /BOSSES_INTENT_UI_PASS/);
});
