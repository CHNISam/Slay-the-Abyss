import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, handPose, theme } from '../scripts/ui-layout.mjs';

const stage = () => battleLayout().controls.find(c => c.name === 'stage');
function walk(controls, fn, x = 0, y = 0) {
  const names = new Set();
  for (const control of controls) {
    assert(!names.has(control.name)); names.add(control.name);
    const cx = x + (control.position?.[0] || 0), cy = y + (control.position?.[1] || 0);
    fn(control, cx, cy);
    if (control.children) walk(control.children, fn, cx, cy);
  }
}
test('the shared theme drives a centered stage with a canvas-filling backdrop outside it', () => {
  const tree = battleLayout();
  assert.deepEqual(stage().size, theme.canvas.base);
  assert.deepEqual(tree.controls[0].anchor, {min: [0.5, 0.5], max: [0.5, 0.5]});
  assert.equal(tree.controls[0].colour, theme.color.backdrop);
  assert.equal(tree.showCursor, true);
  assert.equal(tree.blockCursor, true);
  walk(stage().children, (c, x, y) => {
    // Rotated cards are checked separately, including runtime selected poses.
    if (!/^card\d+$/.test(c.name)) {
      assert(Math.abs(x) + c.size[0] / 2 <= 640, c.name + ' horizontal');
      assert(Math.abs(y) + c.size[1] / 2 <= 360, c.name + ' vertical');
    }
    if (c.text) assert(c.text.minFontSize >= theme.font.minimum, c.name);
  });
});
test('one through ten hand cards, including selection, fit the 40/20 safe area on every canvas', () => {
  for (const [width, height] of [...Object.values(theme.canvas.devices), [1560, 720]]) {
    const k = Math.min(width / 1280, height / 720);
    for (let count = 1; count <= 10; count++) for (let i = 0; i < count; i++) for (const selected of [false, true]) {
      const pose = handPose(count, i, selected);
      const [w, h] = theme.layout.card.size.map(n => n * pose.scale[0]);
      const radians = Math.abs(pose.rotation) * Math.PI / 180;
      const halfW = (w * Math.cos(radians) + h * Math.sin(radians)) / 2;
      const halfH = (h * Math.cos(radians) + w * Math.sin(radians)) / 2;
      assert((Math.abs(pose.position[0]) + halfW) * k <= width / 2 - 40 * k + 1e-8);
      assert((Math.abs(pose.position[1]) + halfH) * k <= height / 2 - 20 * k + 1e-8, `${count}/${i}/${selected} vertical`);
      if (i > 0) assert(pose.position[0] - handPose(count, i - 1, selected).position[0] >= 44);
    }
  }
});
test('native buttons provide all four states and touch hit areas stay inside the safe area', () => {
  const controls = stage().children;
  assert.equal(controls.filter(c => /^card\d+$/.test(c.name)).length, 10);
  walk(controls, (c, x, y) => {
    if (c.kind === 'presetButton') {
      for (const state of ['normal', 'hover', 'pressed', 'disabled']) {
        assert(c.children.some(child => child.name === c.states[state]));
      }
      assert.deepEqual(c.children.find(child => child.name === 'pressed').scale, [0.96, 0.96]);
    }
    if (c.kind === 'cursorArea' || c.kind === 'presetButton') {
      assert(Math.min(...c.size) >= 44);
      assert(Math.abs(x) + c.size[0] / 2 <= 600 + 1e-8, c.name + ' safe x');
      assert(Math.abs(y) + c.size[1] / 2 <= 340 + 1e-8, c.name + ' safe y');
    }
    if (c.name === 'hpFill') { assert.equal(c.mask, true); assert.equal(c.fill.shape, 'horizontal'); }
  });
});
