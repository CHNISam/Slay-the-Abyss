import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
for (const name of ['map', 'click']) test(`mobile ${name} input recovers without exit modal`, () => {
  buildLuaData(); buildUI();
  const result = runLua(`tests/lua/mobile_${name}_recovery.lua`);
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MOBILE_.*_RECOVERY [12] passed/);
});
