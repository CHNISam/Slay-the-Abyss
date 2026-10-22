import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, handPose, theme } from '../scripts/ui-layout.mjs';

const stage = () => battleLayout().controls.find(c => c.name === 'stage');
test('approved critical actor values and card types have native text line room', () => {
  const controls = stage().children;
  for (const unit of controls.filter(c => c.name === 'hero' || /^enemy\d+$/.test(c.name))) {
    for (const name of ['name', 'hp', 'block', 'statuses']) {
      const label = unit.children.find(c => c.name === name);
      assert(label && label.size[1] >= theme.layout.nativeText.lineHeight, `${unit.name}/${name}`);
      assert(label.text.minFontSize >= theme.font.minimum);
    }
  }
  for (const card of controls.filter(c => /^card\d+$/.test(c.name))) {
    assert(card.children.find(c => c.name === 'type').size[1] >= theme.layout.nativeText.lineHeight);
  }
});
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

test('three potion buttons follow shared tokens and clear the HUD, notice, hand and turn controls', () => {
  const controls = stage().children;
  const potions = controls.filter(control => /^potion\d+$/.test(control.name));
  assert.equal(potions.length, 3);
  const notice = controls.find(control => control.name === 'notice');
  assert.deepEqual(notice.position, theme.layout.battleNotice.position);
  assert.deepEqual(notice.size, theme.layout.battleNotice.size);
  function overlaps(a, b) {
    return Math.abs(a.position[0] - b.position[0]) < (a.size[0] + b.size[0]) / 2
      && Math.abs(a.position[1] - b.position[1]) < (a.size[1] + b.size[1]) / 2;
  }
  for (const [i, potion] of potions.entries()) {
    assert.deepEqual(potion.position, theme.layout.battlePotions.origin.map((n, axis) => n + theme.layout.battlePotions.step[axis] * i));
    assert.deepEqual(potion.size, theme.layout.battlePotions.size);
    assert.equal(potion.kind, 'presetButton');
    for (const state of potion.children) {
      const label = state.children.find(control => control.name === 'label');
      assert.equal(label.text.fontSize, theme.font.small);
      assert(label.size[1] >= theme.font.small * 2, `${potion.name} keeps two readable lines`);
    }
    for (const name of ['title', 'player', 'piles', 'notice', 'energyDisc', 'endTurn']) {
      assert(!overlaps(potion, controls.find(control => control.name === name)), `${potion.name}/${name}`);
    }
    for (const other of potions) if (other !== potion) assert(!overlaps(potion, other));
    for (let count = 1; count <= 10; count++) for (let index = 0; index < count; index++) for (const selected of [false, true]) {
      const pose = handPose(count, index, selected);
      const [width, height] = theme.layout.card.size.map(n => n * pose.scale[0]);
      const radians = Math.abs(pose.rotation) * Math.PI / 180;
      assert(!overlaps(potion, {position: pose.position, size: [width * Math.cos(radians) + height * Math.sin(radians),
        height * Math.cos(radians) + width * Math.sin(radians)]}));
    }
  }
});
