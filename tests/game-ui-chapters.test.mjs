import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('real Host retains campaign identity and completes or retries chapter transitions', () => {
  const result=runLua('tests/fixtures/js-owned/tests/lua/game_ui_chapters.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/CHAPTER_HOST_PASS 4/);
});
