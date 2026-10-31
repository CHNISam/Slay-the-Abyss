import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for (const name of ['collection', 'actions', 'ui', 'routes', 'wish', 'transactions']) {
  test(`run score ${name} real integration`, () => {
    const result = runLua(`tests/lua/run_score_${name}.lua`);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /PASS/);
  });
}
