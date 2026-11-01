import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUiTheme } from '../scripts/build-ui-theme.mjs';
import { buildMapLayout } from '../scripts/map-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('ring-free native nodes preserve four states, official icons, full hits and legal controller choices after repaint', () => {
  buildLuaData();
  buildUiTheme();
  buildMapLayout();
  const result = runLua('tests/lua/map_node_visuals.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /MAP_NODE_VISUALS_PASS 4 states/);
});
