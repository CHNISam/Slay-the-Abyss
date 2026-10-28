import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('original V4 frozen DSL text, static targets and resource summaries', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/original_v4_display.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_ORIGINAL_V4_DISPLAY_PASS 13/);
});
