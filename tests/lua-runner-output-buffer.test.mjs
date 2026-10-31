import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLua } from '../scripts/test-lua.mjs';

const MiB = 1024 * 1024;
function fixture(source, action) {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-lua-output-'));
  const script = join(dir, 'output.lua');
  try { writeFileSync(script, source); return action(script); }
  finally { rmSync(dir, { recursive: true, force: true }); }
}
const prefix = "for i=1,1100 do print(string.rep('x', 1000)) end;";
const expectedPrefix = ('x'.repeat(1000) + '\n').repeat(1100);

test('explicit finite buffer captures complete traces including differences beyond the default limit', () => {
  const outputs = ['first', 'second'].map(tail => fixture(`${prefix}print('${tail}')`, script => {
    const result = runLua(script, { maxBuffer: 2 * MiB });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, expectedPrefix + tail + '\n');
    return result.stdout;
  }));
  assert.equal(outputs[0].slice(0, MiB), outputs[1].slice(0, MiB));
  assert.notEqual(outputs[0], outputs[1], 'late state differences must not be truncated into equality');
});

test('default and explicit finite output limits still fail rather than return truncated success', () => {
  for (const [options, lines] of [[{}, 1100], [{ maxBuffer: 2 * MiB }, 2200]]) {
    fixture(`for i=1,${lines} do print(string.rep('x', 1000)) end;print('END')`, script => {
      assert.throws(() => runLua(script, options), error => {
        assert.equal(error.cause?.code, 'ENOBUFS');
        return true;
      });
    });
  }
});

test('Lua assertion after large trace output remains a real nonzero failure', () => {
  fixture(`${prefix}assert(false, 'LATE_ASSERTION_SENTINEL')`, script => {
    const result = runLua(script, { maxBuffer: 2 * MiB });
    assert.notEqual(result.status, 0);
    // Fengari exits immediately on Lua errors; buffered stdout may be partial.
    // Preserve captured diagnostics without ever treating that exit as success.
    assert.ok(result.stdout.startsWith('x'.repeat(1000) + '\n'));
    assert.match(result.stderr, /LATE_ASSERTION_SENTINEL/);
  });
});

test('output buffer must be a positive finite integer', () => {
  fixture("print('must not run')", script => {
    for (const maxBuffer of [0, -1, 1.5, Infinity, NaN, '2097152', null]) {
      assert.throws(() => runLua(script, { maxBuffer }), /positive safe integer/);
    }
  });
});
