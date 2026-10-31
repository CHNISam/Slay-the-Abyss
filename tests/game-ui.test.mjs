import test from 'node:test';
import assert from 'node:assert/strict';
import { buildUI } from '../scripts/build-ui.mjs';
import { gameLayout, resultStats } from '../scripts/game-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';
import { readFileSync, writeFileSync } from 'node:fs';

test('composed native tree has exactly one menu, battle, map and node panel', () => {
  const layout = gameLayout();
  assert.equal(layout.script, 'abyss_ui');
  assert.deepEqual(layout.controls.map(control => control.name).sort(), ['battlePanel', 'characterPanel', 'choicePanel', 'combatRewards', 'deckEntry', 'deckPanel', 'exitEntry', 'exitPanel', 'mapEntry', 'mapPanel', 'menuPanel', 'nodePanel', 'officialBattleBackdrop', 'potionEntry', 'potionPanel', 'prologuePanel', 'relicBar', 'relicEntry', 'relicPanel', 'runMenu', 'victoryEasterEgg']);
  for (const control of layout.controls.filter(control => !['menuPanel', 'exitEntry'].includes(control.name))) {
    assert.equal(control.visible, false, `${control.name} must not bleed through during startup`);
  }
  const backdrop = layout.controls.find(control => control.name === 'officialBattleBackdrop');
  assert.equal(backdrop.kind, 'container');
  assert.deepEqual(backdrop.size, nativeTheme.canvas.base);
  assert.equal(layout.controls[0], backdrop, 'official artwork stays behind every interactive page');
  assert.deepEqual(backdrop.children.map(control => control.name), ['act1_1', 'act1_2', 'act1_3', 'act2_1', 'act2_2', 'act2_3', 'boss1', 'boss2', 'readabilityVeil']);
  for (const control of backdrop.children) {
    assert.equal(control.kind, 'image', 'backgrounds must not intercept page input');
    assert.notEqual(control.focusable, true);
    if (control.name !== 'readabilityVeil') assert.equal(control.visible, false);
  }
  const egg = layout.controls.find(control => control.name === 'victoryEasterEgg');
  assert.equal(egg.isolateNavigation, true);
  const blocker = egg.children.find(control => control.name === 'blocker');
  assert.equal(blocker.kind, 'cursorArea');
  assert.deepEqual(blocker.size, nativeTheme.canvas.base);
  assert.equal(blocker.focusable, false);
  assert.equal(egg.children.find(control => control.name === 'close').children.find(control => control.name === 'hit').kind, 'cursorArea');
  const result = layout.controls.find(control => control.name === 'menuPanel').children.find(control => control.name === 'result');
  assert.equal(result.children.find(control => control.name === 'viewEasterEgg').visible, false, 'victory action starts unavailable');
});

test('title keeps one noninteractive theme-driven version label and no custom announcement', () => {
  const theme = structuredClone(nativeTheme);
  theme.layout.nativeMenu.codeVersion[0] = 25;
  const layout = gameLayout(theme), menu = layout.controls.find(control => control.name === 'menuPanel');
  const version = menu.children.find(control => control.name === 'codeVersion');
  assert.equal(version.kind, 'text');
  assert.equal(version.text.content, '', 'validated version is injected by the existing build');
  assert.equal(version.text.autoSize, false);
  assert.deepEqual(version.position, theme.layout.nativeMenu.codeVersion.slice(0, 2));
  assert.equal(menu.children.some(control => control.name === 'releaseNotes'), false);
  assert.equal(layout.controls.some(control => control.name === 'releaseNotesPanel'), false);
  for (const device of [...Object.values(theme.canvas.devices), [2340, 1080]]) {
    const scale = Math.min(device[0] / theme.canvas.base[0], device[1] / theme.canvas.base[1]);
    for (const [i, margin] of [theme.canvas.safe.x, theme.canvas.safe.y].entries()) {
      assert.ok((Math.abs(version.position[i]) + version.size[i] / 2 + margin) * scale <= device[i] / 2);
    }
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
  const version = JSON.parse(readFileSync('package.json', 'utf8')).version;
  const narrative = readFileSync('build/lua/abyss_narrative.lua', 'utf8');
  assert.ok(narrative.includes(`["codeVersion"]="v${version}"`));
  assert.doesNotMatch(narrative, /releaseNotes|sourceCommit|sourceDirty/,
    'runtime presentation carries only the current version, not announcement history or development identity');
  // Each real-tree fixture retains its bounded runner deadline and all cases.
  const scripts = [
    ['tests/lua/game_ui.lua', /^LUA_GAME_UI_PASS 16$/m],
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
