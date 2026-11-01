import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('source uncommon relic callbacks produce real combat and permanent state changes', () => {
  const result = runLua('tests/lua/uncommon_relics_effects.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_UNCOMMON_RELICS_PASS 13/);
});
test('uncommon effects activate after the normal Run obtain and combat paths', () => {
  const result = runLua('tests/lua/uncommon_relics_lifecycle.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_UNCOMMON_RELIC_LIFECYCLE_PASS 11/);
});
test('Chemical X adds two once across all X cards while preserving zero cost and free autoplay energy', () => {
  const result = runLua('tests/lua/uncommon_relics_x.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_CHEMICAL_X_PASS 12/);
});
test('source TOP, BOTTOM, and synchronous opening relics have real event-frame order evidence', () => {
  const result = runLua('tests/lua/uncommon_relics_opening.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /LUA_SOURCE_OPENING_PASS 13/);
});
