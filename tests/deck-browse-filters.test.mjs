import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('deck browsing filters and sorting remain view-only across run, pile and starter previews', () => {
  const result = runLua('tests/lua/deck_browse_filters.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /DECK_BROWSE_FILTER_PASS 4/);
});
