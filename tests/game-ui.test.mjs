import test from 'node:test';
import assert from 'node:assert/strict';
import { buildUI } from '../scripts/build-ui.mjs';
import { gameLayout, resultStats } from '../scripts/game-ui-layout.mjs';
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

test('menu and result follow the approved win.png composition inside the safe area', () => {
  const theme = nativeTheme, layout = theme.layout.nativeMenu;
  const menu = gameLayout().controls.find(control => control.name === 'menuPanel').children;
  const find = (list, name) => list.find(control => control.name === name);
  assert.equal(find(menu, 'title').text.content, '杀戮深渊');
  const result = find(menu, 'result');
  assert.equal(result.visible, false, 'result cells must not bleed into the main menu');
  assert.deepEqual(resultStats.map(key => find(result.children, `stat_${key}`).position[0]),
    [0, 1, 2, 3].map(i => layout.stats.origin[0] + i * layout.stats.step));
  // Primary restart is gold-filled with dark ink; settlement is the outlined secondary action.
  const start = find(menu, 'start'), settle = find(menu, 'settle');
  assert.equal(find(start.children, 'plate').colour, theme.color.gold);
  assert.equal(find(start.children, 'label').text.colour, theme.color.textOnLight);
  assert.equal(find(settle.children, 'border').colour, theme.color.gold);
  assert.deepEqual(start.size, layout.resultRestart.slice(2));
  // Top-down hierarchy: emblem > title > subtitle > stats > detail > buttons > status, all in the safe area.
  const order = [layout.emblem, layout.title, layout.subtitle, [0, layout.stats.origin[1]], layout.detail, layout.settle, layout.status];
  for (let i = 1; i < order.length; i++) assert.ok(order[i][1] < order[i - 1][1]);
  const [w, h] = theme.canvas.base, { x, y } = theme.canvas.safe;
  for (const frame of [layout.emblem, layout.title, layout.status, layout.start, layout.resultRestart, layout.settle]) {
    assert.ok(Math.abs(frame[0]) + frame[2] / 2 <= w / 2 - x && Math.abs(frame[1]) + frame[3] / 2 <= h / 2 - y);
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
  const partitions = [
    ['game_ui.lua', 'flow', 4],
    ['game_ui_results.lua', 'results', 11],
    ['game_ui_deck.lua', 'deck', 6],
  ];
  const outputs = partitions.map(([file, name, count]) => {
    const result = runLua(`tests/lua/${file}`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, new RegExp(`LUA_GAME_UI_PASS ${name} ${count}(?:\\r?\\n|$)`));
    return result.stdout;
  });
  const stdout = outputs.join('\n');
  const cases = stdout.split(/\r?\n/).filter(line => line.startsWith('ok game UI '));
  assert.equal(cases.length, 21, 'all GameUI cases must execute');
  assert.equal(new Set(cases).size, 21, 'GameUI partitions must not repeat cases');
  const previews = Object.fromEntries(stdout.split(/\r?\n/).filter(line => line.startsWith('LORE_PREVIEW\t'))
    .map(line => { const [, name, text] = line.split('\t'); return [name, text.replaceAll('\\n', '\n')]; }));
  const { nativeMenu: menu, nativeBattle: battle } = nativeTheme.layout, { font: size } = nativeTheme;
  // Each line is checked against the control that actually displays it.
  const targets = { intro: [menu.tagline, size.heading], menu: [menu.summary, size.body],
    victory: [menu.subtitle, size.body], defeat: [menu.subtitle, size.body],
    settlementError: [menu.status, size.small], boss: [battle.notice, size.body] };
  for (const [name, [frame, font]] of Object.entries(targets)) {
    assert.ok(previews[name], `missing actual controller output for ${name}`);
    // Conservative local budget: one full font-size per codepoint, no auto-shrink.
    const lines = previews[name].split('\n');
    const rows = lines.reduce((sum, line) => sum + Math.max(1, Math.ceil([...line].length * font / frame[2])), 0);
    assert.ok(rows * nativeTheme.layout.nativeText.lineHeight <= frame[3], `${name} overflows its existing control`);
  }
  writeFileSync('build/lore-preview.json', JSON.stringify(previews, null, 2) + '\n');
});
