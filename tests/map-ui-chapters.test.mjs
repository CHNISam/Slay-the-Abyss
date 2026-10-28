import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('chapter map controls use local rows while retaining global room identity', () => {
  const result=runLua('tests/fixtures/js-owned/tests/lua/map_ui_chapters.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/CHAPTER_MAP_PASS 3/);
});
