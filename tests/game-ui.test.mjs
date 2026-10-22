import test from 'node:test';
import assert from 'node:assert/strict';
import { buildUI } from '../scripts/build-ui.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';

test('composed native tree has exactly one menu, battle, map and node panel', () => {
  const layout = gameLayout();
  assert.equal(layout.script, 'abyss_ui');
  assert.deepEqual(layout.controls.map(control => control.name).sort(), ['battlePanel', 'mapPanel', 'menuPanel', 'nodePanel']);
  for (const control of layout.controls.filter(control => control.name !== 'menuPanel')) {
    assert.equal(control.visible, false, `${control.name} must not bleed through during startup`);
  }
});

test('result settlement button starts hidden and uses the approved two-button placement', () => {
  const menu = gameLayout().controls.find(control => control.name === 'menuPanel');
  const settle = menu.children.find(control => control.name === 'settle');
  const restart = nativeTheme.layout.nativeMenu.resultRestart;
  assert.equal(settle.visible, false);
  assert.deepEqual(settle.position, nativeTheme.layout.nativeMenu.settle.slice(0, 2));
  assert.ok(restart[0] + restart[2] / 2 < settle.position[0] - settle.size[0] / 2);
  assert.equal(settle.children.find(control => control.name === 'label').text.content, '结束并结算');
  for (const state of ['normal', 'selected', 'disabled']) assert.ok(settle.children.find(control => control.name === state));
});

test('generated Chinese display and native tree exercise the real game entry and run controllers', () => {
  buildUI();
  const result = runLua('tests/lua/game_ui.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_GAME_UI_PASS/);
});
