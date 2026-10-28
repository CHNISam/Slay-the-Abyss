import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeControls, nativeTheme } from '../scripts/native-ui-theme.mjs';
import { battleLayout } from '../scripts/ui-layout.mjs';
import { mapGeometry, mapLayout } from '../scripts/map-ui-layout.mjs';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';

const find = (controls, name) => controls.find(control => control.name === name);
function walk(controls, action) {
  for (const control of controls) { action(control); walk(control.children ?? [], action); }
}
function freeze(value) {
  if (value && typeof value === 'object') { Object.freeze(value); Object.values(value).forEach(freeze); }
  return value;
}

test('native image colours serialize as RGB with independent opacity', () => {
  const plate = nativeControls().plate('veil', [0, 0, 20, 20], '#12345680');
  assert.equal(plate.colour, '#123456');
  assert.equal(plate.opacity, 128 / 255);
  walk(gameLayout().controls, control => {
    if (control.kind !== 'image' || control.colour === undefined) return;
    assert.match(control.colour, /^#[0-9a-f]{6}$/i, control.name);
    if (control.opacity !== undefined) assert.ok(control.opacity >= 0 && control.opacity <= 1);
  });
  const node = nodeLayout().controls[0].children;
  const veils = [];
  walk(node, control => { if (control.name === 'veil') veils.push(control); });
  assert.equal(veils.length, 34, 'shop, legacy picker and twelve-card forge veils use the supported colour representation');
  for (const veil of veils) {
    assert.equal(veil.colour, nativeTheme.color.backdropVeil.slice(0, 7));
    assert.equal(veil.opacity, parseInt(nativeTheme.color.backdropVeil.slice(7), 16) / 255);
  }
});

test('node and menu layouts resolve semantic colour, font, minimum font and picture tokens', () => {
  const theme = structuredClone(nativeTheme);
  theme.color.gold = '#123456'; theme.color.text = '#ABCDEF'; theme.color.panelRaised = '#654321';
  theme.color.node.current = '#AABBCC'; theme.font.title = 32; theme.font.heading = 26; theme.font.body = 20;
  theme.font.minimum = 16; theme.image.rect = 100004;
  const node = nodeLayout(theme).controls[0].children;
  assert.equal(find(node, 'title').text.colour, theme.color.gold);
  assert.equal(find(node, 'title').text.fontSize, theme.font.heading);
  assert.equal(find(node, 'hp').text.fontSize, theme.font.body);
  assert.equal(find(node, 'hp').text.colour, theme.color.text);
  assert.equal(find(find(node, 'back').children, 'normal').colour, theme.color.panelRaised);
  const id = entry => (typeof entry === 'object' ? entry.id : entry);
  const allowed = [theme.image.rect, theme.image.disc, theme.image.ring, theme.image.glow, ...Object.values(theme.icon.cardArt),
    theme.icon.node.treasure, theme.icon.medallion.camp, theme.icon.medallion.treasure, theme.icon.medallion.chestOpen,
    theme.icon.hp, theme.icon.upgrade, theme.icon.remove, theme.icon.back, theme.icon.next, theme.icon.geo,
    id(theme.icon.gold), id(theme.icon.deck), id(theme.icon.potion.fire_potion),
    // The shop merchant's silhouette (hood point, beard) and its next-line marker.
    theme.image.diamond,100001,100002,100003,100004,100006];
  walk(nodeLayout(theme).controls, control => {
    if (control.kind === 'image') assert.ok(allowed.includes(control.image), `unexpected node image ${control.image}`);
    if (control.kind === 'text') assert.equal(control.text.minFontSize, theme.font.minimum);
  });
});

test('host preserves the approved battle and scrollable map while composing node and menu panels', () => {
  const theme = structuredClone(nativeTheme);
  theme.layout.nativeNode.confirm[2] = 220;
  theme.layout.nativeMenu.start[1] = -220;
  theme.layout.battleRewards.return = [-480, -72, 156, 56];
  theme.canvas.base = [1600, 900];
  const panels = gameLayout(theme).controls, battle = find(panels, 'battlePanel').children;
  const approvedBattle = find(battleLayout().controls, 'stage').children;
  assert.deepEqual(battle, approvedBattle);
  assert.deepEqual(find(battle, 'card1').size, nativeTheme.layout.card.size);
  assert.equal(find(battle, 'endTurn').kind, 'presetButton');
  assert.deepEqual(Object.keys(find(battle, 'endTurn').states).sort(), ['disabled', 'hover', 'normal', 'pressed']);
  const map = find(panels, 'mapPanel').children;
  const standaloneMap = find(find(mapLayout(theme).controls, 'stage').children, 'mapPanel').children;
  // The host adds a fixed resource HUD and aligns the title with room headers.
  // Route geometry, scrolling and navigation must still match the standalone map.
  const title = groups => find(groups.flatMap(group => group.children ?? []), 'title');
  assert.deepEqual(title(map).position, theme.layout.nativeNode.topBar.title.slice(0, 2));
  assert.deepEqual(title(map).size, theme.layout.nativeNode.topBar.title.slice(2));
  const resources = find(map, 'resources');
  assert.deepEqual(resources.children.map(control => control.name), ['hpIcon', 'hp', 'goldIcon', 'gold']);
  const previewBack=find(map,'previewBack');
  assert.equal(previewBack.visible,false);
  assert.deepEqual([...previewBack.position,...previewBack.size],theme.layout.runMenu.mapBack);
  const comparableMap = structuredClone(map.filter(group => !['resources','previewBack'].includes(group.name)));
  title(comparableMap).position = [...title(standaloneMap).position];
  title(comparableMap).size = [...title(standaloneMap).size];
  assert.deepEqual(comparableMap, standaloneMap);
  assert.equal(map.flatMap(group => group.children).filter(control => /^node\d+$/.test(control.name)).length,
    mapGeometry(theme).maxNodes);
  assert.equal(find(find(panels, 'nodePanel').children, 'confirm').size[0], 220);
  assert.equal(find(find(panels, 'menuPanel').children, 'start').position[1], -220);
  // Page/overlay roots still fill the canvas. The reward-return control is
  // a standalone button on the same stage, with its own themed touch region.
  const rewardReturn = find(panels, 'combatRewards');
  assert.ok(rewardReturn, 'the standalone reward-return action must exist');
  panels.filter(panel => panel !== rewardReturn).forEach(panel =>
    assert.deepEqual(panel.size, theme.canvas.base, `${panel.name}: full-page root`));
  for (const currentTheme of [nativeTheme, theme]) {
    const action = find(gameLayout(currentTheme).controls, 'combatRewards');
    const frame = currentTheme.layout.battleRewards.return;
    assert.deepEqual([...action.position, ...action.size], frame, 'return action must follow its theme frame');
    assert.equal(action.visible, false, 'return action must not leak into startup or unrelated pages');
    assert.equal(find(action.children, 'label').text.content, '返回战利品');
    const hit = find(action.children, 'hit');
    assert.equal(hit.kind, 'cursorArea');
    assert.equal(hit.focusable, true);
    assert.deepEqual(hit.size, action.size, 'touch region must match the compact action');
    const [width, height] = currentTheme.canvas.base, safe = currentTheme.canvas.safe;
    assert.ok(Math.abs(frame[0]) + frame[2] / 2 <= width / 2 - safe.x, 'return action horizontal safe area');
    assert.ok(Math.abs(frame[1]) + frame[3] / 2 <= height / 2 - safe.y, 'return action vertical safe area');
  }
});

test('building and mutating output trees cannot mutate the source theme', () => {
  const theme = freeze(structuredClone(nativeTheme)), before = JSON.stringify(theme);
  for (const build of [nodeLayout, gameLayout]) walk(build(theme).controls, control => {
    control.size[0] = 1;
    if (control.position) control.position[0] = 1;
  });
  assert.equal(JSON.stringify(theme), before);
});

test('all native text respects the approved readable minimum', () => {
  walk(gameLayout().controls, control => {
    if (control.kind !== 'text') return;
    assert.equal(control.text.minFontSize, nativeTheme.font.minimum);
    assert.ok(control.text.fontSize >= nativeTheme.font.minimum);
  });
});
