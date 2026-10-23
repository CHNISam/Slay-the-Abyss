import test from 'node:test';
import assert from 'node:assert/strict';
import { buildUI } from '../scripts/build-ui.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';
import { writeFileSync } from 'node:fs';

test('composed native tree has exactly one menu, battle, map and node panel', () => {
  const layout = gameLayout();
  assert.equal(layout.script, 'abyss_ui');
  assert.deepEqual(layout.controls.map(control => control.name).sort(), ['battlePanel', 'deckEntry', 'deckPanel', 'mapPanel', 'menuPanel', 'nodePanel']);
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
  const previews = Object.fromEntries(result.stdout.split(/\r?\n/).filter(line => line.startsWith('LORE_PREVIEW\t'))
    .map(line => { const [, name, text] = line.split('\t'); return [name, text.replaceAll('\\n', '\n')]; }));
  const summary = nativeTheme.layout.nativeMenu.summary;
  for (const name of ['menu', 'victory', 'defeat', 'settlementError', 'boss']) {
    assert.ok(previews[name], `missing actual controller output for ${name}`);
    const frame = name === 'boss' ? nativeTheme.layout.nativeBattle.notice : summary;
    const font = name === 'boss' ? nativeTheme.font.body : nativeTheme.font.heading;
    // Conservative local budget: one full font-size per codepoint, no auto-shrink.
    const lines = previews[name].split('\n');
    const rows = lines.reduce((sum, line) => sum + Math.max(1, Math.ceil([...line].length * font / frame[2])), 0);
    assert.ok(rows * nativeTheme.layout.nativeText.lineHeight <= frame[3], `${name} overflows its existing control`);
  }
  writeFileSync('build/lore-preview.json', JSON.stringify(previews, null, 2) + '\n');
});
