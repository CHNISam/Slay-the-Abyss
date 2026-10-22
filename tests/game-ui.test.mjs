import test from 'node:test';
import assert from 'node:assert/strict';
import { buildUI } from '../scripts/build-ui.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('composed native tree has exactly one menu, battle, map and node panel', () => {
  const layout = gameLayout();
  assert.equal(layout.script, 'abyss_ui');
  assert.deepEqual(layout.controls.map(control => control.name).sort(), ['battlePanel', 'mapPanel', 'menuPanel', 'nodePanel']);
});

test('generated Chinese display and native tree exercise the real game entry and run controllers', () => {
  buildUI();
  const result = runLua('tests/lua/game_ui.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_GAME_UI_PASS/);
});
