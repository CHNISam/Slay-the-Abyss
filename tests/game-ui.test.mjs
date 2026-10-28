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
  assert.deepEqual(layout.controls.map(control => control.name).sort(), ['battlePanel', 'combatRewards', 'deckEntry', 'deckPanel', 'exitEntry', 'exitPanel', 'mapPanel', 'menuPanel', 'nodePanel', 'potionEntry', 'potionPanel', 'prologuePanel', 'releaseNotesPanel']);
  for (const control of layout.controls.filter(control => !['menuPanel', 'exitEntry'].includes(control.name))) {
    assert.equal(control.visible, false, `${control.name} must not bleed through during startup`);
  }
});

test('menu and result follow the approved win.png composition inside the safe area', () => {
  const theme = nativeTheme, layout = theme.layout.nativeMenu;
  const menu = gameLayout().controls.find(control => control.name === 'menuPanel').children;
  const find = (list, name) => list.find(control => control.name === name);
  assert.equal(find(menu, 'title').text.content, '杀戮原塔2');
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
  // Each real-tree fixture retains its bounded runner deadline and all cases.
  const scripts = [
    ['tests/lua/game_ui.lua', /^LUA_GAME_UI_PASS 15$/m],
    ['tests/lua/game_ui_deck.lua', /^LUA_GAME_UI_DECK_PASS 6$/m],
    ['tests/lua/game_ui_prologue.lua', /^LUA_GAME_UI_PROLOGUE_PASS 10$/m],
  ];
  const output = scripts.map(([script, marker]) => {
    const result = runLua(script);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, marker);
    return result.stdout;
  }).join('\n');
  const previews = Object.fromEntries(output.split(/\r?\n/).filter(line => line.startsWith('LORE_PREVIEW\t'))
    .map(line => { const [, name, text] = line.split('\t'); return [name, text.replaceAll('\\n', '\n')]; }));
  const { nativeMenu: menu, nativeBattle: battle, prologue } = nativeTheme.layout, { font: size } = nativeTheme;
  // Each line is checked against the control that actually displays it.
  assert.equal(previews.menu, '', 'the start screen has no route or control instructions');
  // The approved intro is told sentence by sentence on the cinematic's single line.
  const targets = { intro1: [prologue.line, size.title], intro2: [prologue.line, size.title], intro3: [prologue.line, size.title],
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

test('the game name appears only on the title screen; other pages name their own scene', () => {
  const layout = gameLayout();
  const named = [];
  const walk = (list, path) => { for (const control of list) {
    const here = path + '/' + control.name;
    if (control.text?.content?.includes('杀戮原塔')) named.push(here);
    walk(control.children ?? [], here);
  } };
  walk(layout.controls, '');
  assert.deepEqual(named, ['/menuPanel/title']);
  const battleTitle = layout.controls.find(c => c.name === 'battlePanel').children.find(c => c.name === 'title');
  assert.equal(battleTitle.text.content, '战斗');
});

test('cinematic and merchant controls stay inside the phone safe area and clear of shop goods', () => {
  const theme = nativeTheme, [w, h] = theme.canvas.base, { x, y } = theme.canvas.safe;
  const { prologue, merchant, nativeNode: node } = theme.layout;
  const inside = ([cx, cy, cw, ch]) => Math.abs(cx) + cw / 2 <= w / 2 - x && Math.abs(cy) + ch / 2 <= h / 2 - y;
  for (const frame of [prologue.line, prologue.chapter, prologue.hint, prologue.skip, merchant.frame, merchant.box, merchant.portrait, merchant.name, merchant.line])
    assert.ok(inside(frame), JSON.stringify(frame));
  // The compact dialogue sits below the goods. Check both axes: colorless
  // prices can share its vertical band while remaining to its left.
  const top = (f) => f[1] + f[3] / 2, bottom = (f) => f[1] - f[3] / 2;
  const prices=[...node.shop.relics.columns.map(cx=>[cx,node.shop.relics.priceY,...node.price.size]),
    ...node.shop.potions.columns.map(cx=>[cx,node.shop.potions.priceY,...node.price.size]),
    [node.shop.removal[0],node.shop.removalPriceY,...node.price.size]];
  for (const price of prices) {
    for (const frame of [merchant.frame, merchant.box, merchant.portrait, merchant.name, merchant.line])
      assert.ok(top(frame)<=bottom(price) || frame[0]+frame[2]/2<=price[0]-price[2]/2 ||
        frame[0]-frame[2]/2>=price[0]+price[2]/2, JSON.stringify(frame));
  }
  assert.ok(merchant.box[0] - merchant.box[2] / 2 > node.back[0] + node.back[2] / 2);
  assert.ok(merchant.box[0] + merchant.box[2] / 2 < node.confirm[0] - node.confirm[2] / 2);
  // The skip button lives in the lower letterbox, away from the persistent exit entry.
  assert.ok(bottom(prologue.skip) >= -h / 2 + y - 1 && top(prologue.skip) <= -h / 2 + prologue.barHeight + 4);
});
