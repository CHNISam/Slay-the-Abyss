import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Awakened One source encounter, phase death, powers and queues preserve the real Combat/Run owners', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/awakened_one.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_AWAKENED_ONE 38 groups; 0 failed/);
});

test('generated battle controls retain a visible untargetable Rebirth and a real second-form death', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/awakened_one_ui.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /AWAKENED_ONE_UI_PASS/);
});

test('halfDead combat preserves non-target choices, exhaust/relic/orb continuations and Sunder source semantics', () => {
  const result = runLua('tests/fixtures/js-owned/tests/lua/awakened_one_presence.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /AWAKENED_ONE_PRESENCE 13 groups; 0 failed/);
});
