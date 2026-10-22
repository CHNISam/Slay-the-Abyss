import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout } from '../scripts/ui-layout.mjs';

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
