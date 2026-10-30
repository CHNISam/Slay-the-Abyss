import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, theme } from '../scripts/ui-layout.mjs';

test('pile view cursor areas cover their existing icons and counts within the safe canvas', () => {
  const stage = battleLayout().controls.find(c => c.name === 'stage');
  const [w, h] = theme.canvas.base;
  for (const name of ['draw', 'discard', 'exhaust']) {
    const icon = stage.children.find(c => c.name === `${name}Icon`);
    assert.equal(icon.kind, 'container', `${name} entry must legally hold its hit area`);
    const image = icon.children.find(c => c.name === 'image');
    assert.equal(image.kind, 'image');
    assert.deepEqual(image.position, [0, 0]);
    assert.deepEqual(image.size, icon.size);
    const target = icon.children.find(c => c.name === 'hit');
    assert.equal(target.kind, 'cursorArea');
    assert.equal(target.focusable, true);
    const [x, y] = icon.position.map((value, axis) => value + target.position[axis]);
    const [tw, th] = target.size;
    assert.ok(tw >= theme.layout.topBar.height && th >= theme.layout.topBar.height, name);
    assert.ok(x - tw / 2 >= -w / 2 + theme.canvas.safe.x, name);
    assert.ok(x + tw / 2 <= w / 2 - theme.canvas.safe.x, name);
    assert.ok(y - th / 2 >= -h / 2 + theme.canvas.safe.y, name);
    assert.ok(y + th / 2 <= h / 2 - theme.canvas.safe.y, name);
    const count = stage.children.find(c => c.name === name);
    assert.ok(Math.abs(count.position[0] - x) <= tw / 2, `${name} count is clickable`);
    assert.ok(Math.abs(count.position[1] - y) <= th / 2, `${name} count is clickable`);
    assert.equal(count.kind, 'text');
  }
});

test('pile entry additions preserve every existing stage path and the native 60-child limit', () => {
  const root = battleLayout();
  function visit(controls) {
    assert.ok(controls.length <= 60);
    assert.equal(new Set(controls.map(c => c.name)).size, controls.length);
    for (const control of controls) visit(control.children ?? []);
  }
  visit(root.controls);
  const stage = root.controls.find(c => c.name === 'stage');
  assert.equal(stage.children.length, 56);
  assert(stage.children.some(c=>c.name==='actorLayer'));
  assert(!stage.children.some(c=>/^enemy\d+$/.test(c.name)),'actors are per-instance, not five static scene children');
  for (const name of ['drawIcon', 'draw', 'drawLabel', 'discardIcon', 'discard', 'discardLabel', 'exhaustIcon', 'exhaust']) {
    assert.ok(stage.children.find(c => c.name === name), name);
  }
});
