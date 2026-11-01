import test from 'node:test';
import assert from 'node:assert/strict';
import { mapLayout, loadMapTheme } from '../scripts/map-ui-layout.mjs';

const theme = loadMapTheme();
const controls = mapLayout(theme).controls[1].children[0].children.flatMap(group => group.children);
const get = name => {
  const control = controls.find(item => item.name === name);
  assert.ok(control, `missing map control: ${name}`);
  return control;
};
const bounds = control => ({
  left: control.position[0] - control.size[0] / 2,
  right: control.position[0] + control.size[0] / 2,
  bottom: control.position[1] - control.size[1] / 2,
  top: control.position[1] + control.size[1] / 2,
});
const intersects = (a, b) => a.left < b.right && a.right > b.left && a.bottom < b.top && a.top > b.bottom;

test('controller paging avoids node-type legend without adding a recenter button', () => {
  const legend = get('typeLegend');
  const lb = bounds(legend);
  for (const name of ['next', 'previous']) {
    const button = get(name);
    assert.equal(button.visible, false, 'paging is controller-only at runtime');
    const bb = bounds(button);
    assert.equal(intersects(bb, lb), false, `${name} overlaps node-type legend`);
    assert.ok(bb.bottom >= lb.top + 8, `${name} needs a readable gap above the legend`);
    assert.ok(bb.top <= theme.layout.map.viewportHeight - 308,
      `${name} must stay below the HUD / top map viewport boundary`);
    assert.ok(bb.right <= theme.canvas.base[0] / 2 - theme.canvas.safe.x);
    assert.ok(bb.left >= -theme.canvas.base[0] / 2 + theme.canvas.safe.x);
    assert.deepEqual(button.children.find(c => c.name === 'hit').size, button.size);
  }
});

test('navigation hit areas are disjoint without moving the shared type legend', () => {
  const buttons = ['next', 'previous'].map(get);
  for (let i = 0; i < buttons.length; i++) {
    for (let j = i + 1; j < buttons.length; j++) {
      assert.equal(intersects(bounds(buttons[i]), bounds(buttons[j])), false,
        `${buttons[i].name} and ${buttons[j].name} overlap`);
    }
  }
  assert.equal(controls.some(c => c.name === 'focus'), false, 'the non-original recenter button must not exist');
  assert.deepEqual(get('typeLegend').position, theme.layout.map.presentation.typeLegend.position);
  assert.deepEqual(get('typeLegend').size, theme.layout.map.presentation.typeLegend.size);
});
