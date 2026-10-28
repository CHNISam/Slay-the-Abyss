import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

for (const [file, marker] of [
  ['ending_proceed_nodes.lua', 'ENDING_PROCEED_NODES 4 groups; 0 failed; natural/platform NOT_RUN'],
  ['ending_proceed_ui.lua', 'ENDING_PROCEED_UI 3 groups; 0 failed; native/natural NOT_RUN'],
]) test(`Heart explicit Proceed boundary: ${file}`, () => {
  const result = runLua(`tests/fixtures/js-owned/tests/lua/${file}`);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(result.stdout.includes(marker), result.stdout);
});
