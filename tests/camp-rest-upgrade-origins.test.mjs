import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('public camp rest preserves actual card UID, upgrade state and distinct acquisition sources', () => {
  const result = runLua('tests/lua/camp_rest_upgrade_origins.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /CAMP_REST_UPGRADE_ORIGINS_PASS 2/);
});
