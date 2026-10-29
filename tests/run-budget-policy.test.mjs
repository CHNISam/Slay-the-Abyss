import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewModuleSize, reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';

test('Run size rejects 1001 physical lines and accepts 1000 with either newline convention', () => {
  const file = 'src/lua/abyss_run.lua';
  for (const newline of ['\n', '\r\n']) {
    for (const trailing of ['', newline]) {
      assert.deepEqual(reviewModuleSize({[file]: Array(1000).fill('-- line').join(newline) + trailing}, {[file]:1000}).errors, []);
      assert.ok(reviewModuleSize({[file]: Array(1001).fill('-- line').join(newline) + trailing}, {[file]:1000}).errors.length);
    }
  }
  assert.ok(reviewModuleSize({}).errors.length);
});

test('Run whole-file and extracted helper budgets reject an unlisted function and nested callback at 16', () => {
  for (const file of ['src/lua/abyss_run.lua', 'src/lua/abyss_run_future.lua']) {
    const source = 'local function unrelated() return function() end end';
    const row = (column, subject, value) => ({file, line:1, column, code:'W561',
      message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
    const rows = [row(1, 'main chunk', 1), row(7, "function 'unrelated'", 15), row(35, 'function', 16)];
    assert.ok(reviewResponsibilityComplexity(rows, {[file]:source}, {}).errors.some(e => e.message.includes('16 exceeds 15')));
    rows[2] = row(35, 'function', 15);
    assert.deepEqual(reviewResponsibilityComplexity(rows, {[file]:source}, {}).errors, []);
    rows[1] = row(7, "function 'unrelated'", 16);
    assert.ok(reviewResponsibilityComplexity(rows, {[file]:source}, {}).errors.some(e => e.message.includes('16 exceeds 15')));
  }
});
