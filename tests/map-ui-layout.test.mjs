import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildMapLayout, buildMapUI, loadMapTheme, mapGeometry, mapLayout } from '../scripts/map-ui-layout.mjs';
import { buildUiTheme } from '../scripts/build-ui-theme.mjs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

const theme = loadMapTheme(), layout = mapLayout(theme), geometry = mapGeometry(theme);
const stage = layout.controls.find(c => c.name === 'stage');
const panel = stage.children.find(c => c.name === 'mapPanel');
const index = new Map(panel.children.flatMap(group => group.children).map(control => [control.name, control]));

test('map uses the approved stage, external backdrop, viewport and shared theme geometry', () => {
  assert.deepEqual(stage.size, theme.canvas.base);
  assert.equal(layout.controls[0].name, 'mapBackdrop');
  assert.equal(layout.controls[0].colour, theme.color.backdrop);
  assert.equal(geometry.viewport.top - geometry.viewport.bottom, theme.layout.map.viewportHeight);
  assert.equal(geometry.viewport.top - geometry.viewport.bottom, 600);
  const altered = structuredClone(theme);
  altered.color.node.current = '#123456';
  altered.image.disc = 106026;
  altered.layout.map.node = 60;
  altered.layout.map.scrollStepFloors = 1;
  altered.motion.base = .24;
  assert.equal(mapGeometry(altered).scrollStep, altered.layout.map.floorGap);
  assert.equal(mapGeometry(altered).scrollSeconds, .24);
  const changed = mapLayout(altered).controls[1].children[0].children.flatMap(group => group.children).find(c => c.name === 'node1');
  assert.equal(changed.children.find(c => c.name === 'current').colour, '#123456');
  assert.equal(changed.children.find(c => c.name === 'current').image, 106026);
  assert.deepEqual(changed.size, [60, 60]);
});

test('static controls are native, readable, unique and fit phone and console safe areas', () => {
  function visit(control, parentX = 0, parentY = 0, hidden = false) {
    assert(['container', 'image', 'text', 'cursorArea'].includes(control.kind));
    const [x, y] = control.position ?? [0, 0], [w, h] = control.size;
    const gx = parentX + x, gy = parentY + y;
    hidden ||= control.visible === false;
    assert(Math.abs(gx) + w / 2 <= 640.01, control.name);
    assert(Math.abs(gy) + h / 2 <= 360.01, control.name);
    if (control.text) assert(control.text.fontSize >= theme.font.minimum);
    if (control.kind === 'cursorArea') {
      assert(w >= 44 && h >= 44);
      if (!hidden) for (const [cw, ch] of [[1280, 720], [1600, 900], [1920, 1080], [2340, 1080]]) {
        const k = Math.min(cw / 1280, ch / 720);
        assert(Math.abs(gx * k) + w * k / 2 <= cw / 2 - theme.canvas.safe.x * k);
        assert(Math.abs(gy * k) + h * k / 2 <= ch / 2 - theme.canvas.safe.y * k);
      }
    }
    const children = control.children ?? [];
    assert.equal(new Set(children.map(child => child.name)).size, children.length);
    for (const child of children) visit(child, gx, gy, hidden);
  }
  for (const control of layout.controls) visit(control);
  const buttons = ['previous', 'focus', 'next'].map(name => index.get(name));
  for (let i = 0; i < buttons.length; i++) for (let j = i + 1; j < buttons.length; j++) {
    assert(Math.abs(buttons[i].position[1] - buttons[j].position[1]) >= (buttons[i].size[1] + buttons[j].size[1]) / 2);
  }
});

test('node and edge pools match controller contract, with seven real icon legend entries', () => {
  for (let i = 1; i <= geometry.maxNodes; i++) {
    const node = index.get(`node${i}`);
    assert.equal(node.visible, false);
    for (const name of ['locked', 'visited', 'current', 'available', 'body', 'icon', 'glow', 'hit']) {
      assert(node.children.some(child => child.name === name), name);
    }
  }
  for (let i = 1; i <= geometry.maxEdges; i++) assert.equal(index.get(`edge${i}`).visible, false);
  for (const [kind, image] of Object.entries(theme.icon.node)) assert.equal(index.get(`legend_${kind}`).image, image);
});

test('custom output directory receives the standalone controls and both Lua map artifacts', () => {
  const outputDirectory = mkdtempSync(join(tmpdir(), 'abyss-map-build-'));
  try {
    buildMapUI(outputDirectory);
    assert.deepEqual(JSON.parse(readFileSync(join(outputDirectory, 'map-ui.json'), 'utf8')), layout);
    assert.match(readFileSync(join(outputDirectory, 'abyss_map_layout.lua'), 'utf8'), /maxScroll/);
    assert.match(readFileSync(join(outputDirectory, 'abyss_map_controls.lua'), 'utf8'), /mapPanel/);
  } finally {
    rmSync(outputDirectory, { recursive: true, force: true });
  }
});

test('actual Lua controller validates navigation, scroll, locked input, path and multi-device geometry', () => {
  buildUiTheme();
  buildLuaData();
  buildMapLayout();
  const result = runLua('tests/lua/map_ui.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MAP_UI_PASS 27/);
});

 test('complete native interface respects MCP per-container import limits', async () => {
  const { gameLayout } = await import('../scripts/game-ui-layout.mjs');
  const visit = control => {
    assert((control.children ?? []).length <= 60, control.name);
    for (const child of control.children ?? []) visit(child);
  };
  for (const control of gameLayout().controls) visit(control);
});
