import test from 'node:test';
import assert from 'node:assert/strict';
import { nodeGeometry, nodeLayout } from '../scripts/node-ui-layout.mjs';

const panel = nodeLayout().controls[0];
const controls = panel.children;
const buttons = controls.filter(c => c.kind === 'container');
const bounds = c => ({ left: c.position[0] - c.size[0] / 2, right: c.position[0] + c.size[0] / 2,
  bottom: c.position[1] - c.size[1] / 2, top: c.position[1] + c.size[1] / 2 });
const overlaps = (a, b) => a.left < b.right && a.right > b.left && a.bottom < b.top && a.top > b.bottom;

test('node panel exports the agreed eight-slot native control contract', () => {
  assert.equal(panel.name, 'nodePanel');
  assert.deepEqual(panel.size, [1280, 720]);
  assert.deepEqual(controls.find(c => c.name === 'title').position, [0, 310]);
  assert.deepEqual(controls.find(c => c.name === 'resources').position, [0, 265]);
  assert.deepEqual(controls.find(c => c.name === 'notice').position, [0, 220]);
  const names = new Set(controls.map(c => c.name));
  assert.equal(names.size, controls.length);
  for (let i = 1; i <= nodeGeometry.pageSize; i++) {
    const c = controls.find(c => c.name === `action${i}`);
    assert.deepEqual(c.size, [540, 80]);
    assert.deepEqual(c.position, [nodeGeometry.columns[(i - 1) % 2], nodeGeometry.rows[Math.floor((i - 1) / 2)]]);
  }
});
test('visible content remains inside the 1280x720 safe area with no sibling overlap', () => {
  for (const c of controls) {
    if (c.name === 'backdrop') continue;
    const box = bounds(c);
    assert.ok(box.left >= -600 && box.right <= 600 && box.bottom >= -340 && box.top <= 340, c.name);
  }
  for (const shop of [true, false]) {
    const content = controls.filter(c => c.name !== 'backdrop' && !(shop ? /^action/.test(c.name) : /^shop/.test(c.name)));
    for (let i = 0; i < content.length; i++) for (let j = i + 1; j < content.length; j++)
      assert.ok(!overlaps(bounds(content[i]), bounds(content[j])), `${content[i].name} overlaps ${content[j].name}`);
  }
});
test('shop gives names, effects and price/status separate non-overlapping readable text boxes', () => {
  for (const item of controls.filter(c => /^shop\d+$/.test(c.name))) {
    const boxes = ['name', 'description', 'price'].map(name => item.children.find(c => c.name === name));
    for (const box of boxes) {
      assert.ok(box.size[1] >= 40, `${item.name}.${box.name}`);
      assert.ok(box.text.fontSize >= 14);
    }
    for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++)
      assert.ok(!overlaps(bounds(boxes[i]), bounds(boxes[j])));
    assert.deepEqual(item.children.find(c => c.name === 'unavailablePrice').size, boxes[2].size);
  }
});
test('all buttons have full size focusable touch targets and readable state layers', () => {
  for (const button of buttons) {
    const hit = button.children.find(c => c.name === 'hit');
    assert.equal(hit.kind, 'cursorArea');
    assert.equal(hit.focusable, true);
    assert.deepEqual(hit.size, button.size);
    assert.ok(hit.size.every(value => value >= 44));
    for (const name of ['normal', 'disabled', 'selected', 'label']) assert.ok(button.children.find(c => c.name === name));
    const label = button.children.find(c => c.name === 'label');
    assert.ok(label.text.minFontSize >= 14);
    assert.ok(label.size[0] < button.size[0] && label.size[1] < button.size[1]);
  }
});
