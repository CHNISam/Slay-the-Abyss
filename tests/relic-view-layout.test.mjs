import test from 'node:test';
import assert from 'node:assert/strict';
import { relicViewControls } from '../scripts/relic-view-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { mapGeometry } from '../scripts/map-ui-layout.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';

const frame = c => [...(c.position ?? [0, 0]), ...c.size];
const clear = (a, b) => Math.abs(a[0] - b[0]) >= (a[2] + b[2]) / 2 ||
  Math.abs(a[1] - b[1]) >= (a[3] + b[3]) / 2;
function assertBarGeometry(t) {
  const [bar] = relicViewControls(t), [tray, ...slots] = bar.children;
  const obstacles = Object.values(t.layout.nativeNode.topBar);
  // Final battle controls use a different top-row height from node/map HUDs.
  const battle = gameLayout(t).controls.find(c => c.name === 'battlePanel');
  obstacles.push(...battle.children.filter(c => c.position?.[1] >= 300).map(frame));
  for (const key of ['relicEntry', 'entry']) obstacles.push(t.layout.deckView[key]);
  const frames = [frame(tray)];
  for (const slot of slots) {
    frames.push(frame(slot));
    const hit = slot.children.find(c => c.name === 'hit');
    assert.equal(hit.kind, 'cursorArea'); assert.equal(hit.focusable, true);
    assert.deepEqual(hit.size, [t.layout.relicView.bar.step, 44]);
    const [x, y] = hit.position ?? [0, 0];
    assert.ok(Math.abs(x) + slot.size[0] / 2 <= hit.size[0] / 2 &&
      Math.abs(y) + slot.size[1] / 2 <= hit.size[1] / 2, 'hit covers the entire relic disc');
    frames.push([slot.position[0] + x, slot.position[1] + y, ...hit.size]);
  }
  for (const f of frames) {
    assert.ok(Math.abs(f[0]) + f[2] / 2 <= t.canvas.base[0] / 2 &&
      Math.abs(f[1]) + f[3] / 2 <= t.canvas.base[1] / 2, 'relic visual/hit stays on canvas');
    for (const obstacle of obstacles) assert.ok(clear(f, obstacle), 'relic visual/hit clears main HUD in 2D');
  }
  for (let i = 1; i < slots.length; i++) {
    const a = frames[2 * i], b = frames[2 * (i + 1)];
    assert.ok(clear(a, b), 'adjacent relic hit areas never overlap');
  }
}

test('owned relics use disc art slots in the top bar and detail rows', () => {
  const [bar, panel] = relicViewControls(theme), v = theme.layout.relicView;
  assert.equal(bar.name, 'relicBar');
  const [tray, ...slots] = bar.children;
  assert.equal(tray.name, 'tray');
  assert.equal(slots.length, v.bar.count);
  // Relics now occupy a second row; preserve separation in both axes, not X alone.
  assert.equal(slots.length, 12);
  assertBarGeometry(theme);
  slots.forEach((slot, i) => {
    assert.ok(Math.abs(slot.position[0] - v.bar.tray[0]) + v.bar.disc / 2 <= v.bar.tray[2] / 2, 'disc inside tray');
    assert.deepEqual(slot.position, [v.bar.origin[0] + v.bar.step * i, v.bar.origin[1]]);
    assert.deepEqual(slot.size, [v.bar.disc, v.bar.disc]);
    assert.deepEqual(slot.children.map(c => c.name), ['rim', 'face', 'icon', 'more', 'hit']);
    assert.equal(slot.children[0].image, theme.image.disc);
    assert.ok(Math.abs(slot.position[1] - v.bar.tray[1]) + v.bar.disc / 2 <= v.bar.tray[3] / 2, 'disc vertically inside tray');
    if (i) assert.ok(slot.position[0] - slots[i - 1].position[0] >= v.bar.disc, 'discs never overlap');
  });
  const rows = panel.children.filter(c => /^row\d+$/.test(c.name));
  assert.equal(rows.length, v.rows.length * v.columns.length);
  for (const row of rows) {
    const names = row.children.map(c => c.name);
    for (const n of ['slot', 'name', 'chip', 'description']) assert.ok(names.includes(n), n);
    const slot = row.children.find(c => c.name === 'slot');
    assert.deepEqual(slot.size, [v.disc, v.disc]);
    assert.ok(slot.position[0] + v.disc / 2 < v.name[0] - v.name[2] / 2, 'name clears the art disc');
    assert.ok(Math.abs(row.position[0]) + v.row[0] / 2 <= v.panel[2] / 2);
  }
  assert.equal(panel.isolateNavigation, true);
  const json = JSON.stringify(panel);
  assert.doesNotMatch(json.replace(/"(name|kind|image|align|valign|colour)":"[^"]*"/g, ''), /"content":"[A-Za-z]{3,}/);
});

test('second-row geometry rejects the old overlapping row and off-canvas click areas', () => {
  const old = structuredClone(theme);
  old.layout.relicView.bar.origin[1] = old.layout.relicView.bar.tray[1] = 282;
  assert.throws(() => assertBarGeometry(old), /clears main HUD/);
  const wide = structuredClone(theme); wide.layout.relicView.bar.origin[0] = -640;
  assert.throws(() => assertBarGeometry(wide), /stays on canvas/);
});

test('map drawings and input viewport reserve the second-row relic hit band', () => {
  const g = mapGeometry(theme), [bar] = relicViewControls(theme);
  for (const slot of bar.children.slice(1)) {
    const hit = slot.children.find(c => c.name === 'hit');
    assert.ok(g.viewport.top <= slot.position[1] - hit.size[1] / 2, 'map must end below relic click areas');
  }
  assert.equal(g.maxScroll, g.contentHeight - (g.viewport.top - g.viewport.bottom));
});

test('real map nodes and focus never share second-row relic click areas', async () => {
  const { buildLuaData } = await import('../scripts/build-lua-data.mjs');
  const { buildUI } = await import('../scripts/build-ui.mjs');
  const { runLua } = await import('../scripts/test-lua.mjs');
  buildLuaData(); buildUI();
  const r = runLua('tests/lua/relic_map_clearance.lua');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /RELIC_MAP_CLEARANCE_PASS/);
});
