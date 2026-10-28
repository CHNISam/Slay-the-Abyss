import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('current canvas intent ordering and bounded signed status stacks run through native controls', () => {
 const result=runLua('tests/lua/ui_final_presentation.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/UI_FINAL_PRESENTATION_PASS/);
});
