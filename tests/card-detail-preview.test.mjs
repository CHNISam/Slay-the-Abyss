import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('card details and upgrade previews preserve current instances and the entire run', () => {
 const result=runLua('tests/lua/card_detail_preview.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CARD_DETAIL_PREVIEW_PASS 11/);
});
