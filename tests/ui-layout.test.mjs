import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout } from '../scripts/ui-layout.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';

test('every native control fits phone, computer and console canvases including children', () => {
  const layout = battleLayout();
  function visit(controls, x = 0, y = 0) {
    const names = new Set();
    for (const c of controls) {
      assert(!names.has(c.name)); names.add(c.name);
      const cx = x + (c.position?.[0] || 0), cy = y + (c.position?.[1] || 0);
      assert(Math.abs(cx) + c.size[0] / 2 <= 640, c.name + ' horizontal');
      assert(Math.abs(cy) + c.size[1] / 2 <= 360, c.name + ' vertical');
      if (c.children) visit(c.children, cx, cy);
    }
  }
  visit(layout.controls);
  assert.equal(layout.showCursor, true);
  assert.equal(layout.blockCursor, true);
});
test('native hit areas remain large enough for touch and all ten hand slots exist', () => {
  const controls = battleLayout().controls;
  assert.equal(controls.filter(c => /^card\d+$/.test(c.name)).length, 10);
  for (const c of controls.filter(c => c.children)) {
    const hit = c.children.find(child => child.kind === 'cursorArea');
    assert(hit && Math.min(...hit.size) >= 44, c.name);
  }
});

test('battle cards, potions and turn button do not overlap and fit the approved touch safe area', () => {
  const controls = battleLayout().controls.filter(control => /^(card|potion)\d+$/.test(control.name) || control.name === 'endTurn');
  const [width, height] = nativeTheme.canvas.base;
  const safe = nativeTheme.canvas.safe;
  for (const control of controls) {
    assert(Math.abs(control.position[0]) + control.size[0] / 2 <= width / 2 - safe.x, control.name);
    assert(Math.abs(control.position[1]) + control.size[1] / 2 <= height / 2 - safe.y, control.name);
  }
  for (let i = 0; i < controls.length; i++) for (let j = i + 1; j < controls.length; j++) {
    const a = controls[i], b = controls[j];
    assert(Math.abs(a.position[0] - b.position[0]) >= (a.size[0] + b.size[0]) / 2 ||
      Math.abs(a.position[1] - b.position[1]) >= (a.size[1] + b.size[1]) / 2, `${a.name} overlaps ${b.name}`);
  }
});
