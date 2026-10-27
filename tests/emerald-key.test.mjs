import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('public Emerald entry validates the original canonical map and continuous source stream before setup', () => {
  const result = runLua('tests/lua/emerald_entry_provenance.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /EMERALD_ENTRY_PROVENANCE 4 groups; 0 failed/);
});

test('Emerald actual Run/Nodes lifecycle preserves birth context, source boost, independent rewards and rollback', () => {
  const result = runLua('tests/lua/emerald_key_run.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /EMERALD_KEY_RUN 6 groups; 0 failed; natural\/platform NOT_RUN/);
});
