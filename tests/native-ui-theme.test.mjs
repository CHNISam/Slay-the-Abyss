import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';
import { battleLayout } from '../scripts/ui-layout.mjs';
import { mapLayout } from '../scripts/map-ui-layout.mjs';
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

test('native layouts resolve semantic colour, font, minimum font and picture tokens', () => {
  const theme = structuredClone(nativeTheme);
  theme.color.gold = '#123456'; theme.color.text = '#ABCDEF'; theme.color.panelRaised = '#654321';
  theme.color.node.current = '#AABBCC'; theme.font.title = 32; theme.font.body = 20;
  theme.font.minimum = 16; theme.image.rect = 100004;
  const battle = battleLayout(theme).controls, map = mapLayout(theme).controls[0].children;
  assert.equal(find(battle, 'title').text.colour, theme.color.gold);
  assert.equal(find(battle, 'title').text.fontSize, theme.font.title);
  assert.equal(find(battle, 'player').text.fontSize, theme.font.body);
  assert.equal(find(battle, 'player').text.colour, theme.color.text);
  assert.equal(find(find(map, 'node1').children, 'current').colour, theme.color.node.current);
  assert.equal(find(find(battle, 'endTurn').children, 'plate').colour, theme.color.panelRaised);
  for (const build of [battleLayout, mapLayout, nodeLayout, gameLayout]) walk(build(theme).controls, control => {
    if (control.kind === 'image') assert.equal(control.image, theme.image.rect);
    if (control.kind === 'text') assert.equal(control.text.minFontSize, theme.font.minimum);
  });
});

test('native geometry, spacing and canvas tokens reach all four generated panels', () => {
  const theme = structuredClone(nativeTheme);
  theme.layout.nativeBattle.enemy.origin[0] += 10;
  theme.layout.nativeBattle.buttonInset[0] += 4;
  theme.layout.nativeMap.geometry.columns[0] += 8;
  theme.layout.nativeMap.edgeWidth = 5;
  theme.layout.nativeNode.geometry.actionSize[0] = 520;
  theme.layout.nativeMenu.start[1] = -220;
  theme.canvas.base = [1600, 900];
  const panels = gameLayout(theme).controls, battle = find(panels, 'battlePanel').children;
  assert.equal(find(battle, 'enemy1').position[0], theme.layout.nativeBattle.enemy.origin[0]);
  assert.equal(find(find(battle, 'endTurn').children, 'label').size[0],
    theme.layout.nativeBattle.endTurn[2] - theme.layout.nativeBattle.buttonInset[0]);
  const map = find(panels, 'mapPanel').children;
  assert.equal(find(map, 'node1').position[0], theme.layout.nativeMap.geometry.columns[0]);
  assert.equal(find(map, 'edge1_1_1_normal').size[1], theme.layout.nativeMap.edgeWidth);
  assert.equal(find(find(panels, 'nodePanel').children, 'action1').size[0], 520);
  assert.equal(find(find(panels, 'menuPanel').children, 'start').position[1], -220);
  panels.forEach(panel => assert.deepEqual(panel.size, theme.canvas.base));
});

test('building and mutating output trees cannot mutate the source theme', () => {
  const theme = freeze(structuredClone(nativeTheme)), before = JSON.stringify(theme);
  for (const build of [battleLayout, mapLayout, nodeLayout, gameLayout]) walk(build(theme).controls, control => {
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
