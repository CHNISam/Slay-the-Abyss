import test from 'node:test';
import assert from 'node:assert/strict';
import { mapLayout } from '../scripts/map-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

const panel = mapLayout().controls[0];
const index = new Map(panel.children.map(control => [control.name, control]));
test('map uses native controls with unique sibling names and stays inside the phone canvas', () => {
  let touches = 0;
  function visit(control, parentX = 0, parentY = 0) {
    assert(['container', 'image', 'text', 'cursorArea'].includes(control.kind));
    const [x, y] = control.position ?? [0, 0], [w, h] = control.size;
    const gx = parentX + x, gy = parentY + y;
    const angle = (control.rotation ?? 0) * Math.PI / 180;
    const boundW = Math.abs(w * Math.cos(angle)) + Math.abs(h * Math.sin(angle));
    const boundH = Math.abs(h * Math.cos(angle)) + Math.abs(w * Math.sin(angle));
    assert(Math.abs(gx) + boundW / 2 <= 640.01, `${control.name} horizontal bounds`);
    assert(Math.abs(gy) + boundH / 2 <= 360.01, `${control.name} vertical bounds`);
    if (control.kind === 'cursorArea') { assert(w >= 44 && h >= 44); touches++; }
    const children = control.children ?? [];
    assert.equal(new Set(children.map(child => child.name)).size, children.length);
    for (const child of children) visit(child, gx, gy);
  }
  visit(panel);
  assert.equal(touches, 18);
});
test('page slots and graph-edge controls satisfy the Lua controller contract', () => {
  assert.equal(panel.name, 'mapPanel');
  for (const name of ['page', 'notice', 'previous', 'next', 'focus']) assert(index.has(name));
  for (let row = 1; row <= 5; row++) {
    assert(index.has(`floor${row}`));
    for (let lane = 1; lane <= 3; lane++) {
      const node = index.get(`node${(row - 1) * 3 + lane}`);
      for (const name of ['locked', 'visited', 'current', 'available', 'label', 'status', 'route', 'hit']) {
        assert(node.children.some(child => child.name === name));
      }
    }
    if (row < 5) for (let from = 1; from <= 3; from++) for (let to = 1; to <= 3; to++) {
      if (Math.abs(from - to) <= 1) for (const state of ['normal', 'taken']) assert(index.has(`edge${row}_${from}_${to}_${state}`));
    }
  }
});
test('adjacent node hit targets and navigation buttons do not overlap', () => {
  const controls = [...Array.from({ length: 15 }, (_, i) => index.get(`node${i + 1}`)),
    ...['previous', 'focus', 'next'].map(name => index.get(name))];
  for (let i = 0; i < controls.length; i++) for (let j = i + 1; j < controls.length; j++) {
    const a = controls[i], b = controls[j];
    assert(Math.abs(a.position[0] - b.position[0]) >= (a.size[0] + b.size[0]) / 2 ||
      Math.abs(a.position[1] - b.position[1]) >= (a.size[1] + b.size[1]) / 2, `${a.name} overlaps ${b.name}`);
  }
});
test('map UI actual Lua click and navigation tests pass in Fengari', () => {
  const result = runLua('tests/lua/map_ui.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /LUA_MAP_UI_PASS 6/);
});
