import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { buildUI } from '../scripts/build-ui.mjs';

const find = (c, name) => c.name === name ? c : c.children?.map(x => find(x, name)).find(Boolean);
test('map resources stay above the route and clear all top-bar controls', () => {
  const layout = { children: gameLayout().controls }, map = find(layout, 'mapPanel'), resources = find(map, 'resources');
  assert.ok(resources, 'money and health must be visible before choosing a room');
  const boxes = [...resources.children, find(map, 'title'),
    find(find(layout, 'potionEntry'), 'open'), find(find(layout, 'deckEntry'), 'open'),
    find(find(layout, 'exitEntry'), 'open')];
  for (const [i, a] of boxes.entries()) {
    assert.ok(a.position[1] - a.size[1] / 2 >= 292, `${a.name} intrudes into the route`);
    assert.ok(Math.abs(a.position[0]) + a.size[0] / 2 <= theme.canvas.base[0] / 2 - theme.canvas.safe.x);
    assert.ok(Math.abs(a.position[1]) + a.size[1] / 2 <= theme.canvas.base[1] / 2 - theme.canvas.safe.y);
    for (const b of boxes.slice(i + 1)) assert.equal(a.position.every((p, axis) =>
      Math.abs(p - b.position[axis]) < (a.size[axis] + b.size[axis]) / 2), false, `${a.name} overlaps ${b.name}`);
  }
  assert.deepEqual(find(resources, 'gold').size, theme.layout.nativeNode.topBar.gold.slice(2));
});
test('map shows actual run resources before entry and refreshes after resource changes', () => {
  buildUI();
  const result = runLua('tests/fixtures/js-owned/tests/lua/map_resources.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MAP_RESOURCES_PASS/);
});
