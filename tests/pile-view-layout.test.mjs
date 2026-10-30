import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, enemyUnitTemplate, enemyPowerTemplate, theme } from '../scripts/ui-layout.mjs';

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

test('pile entries coexist with the dynamic actor host and keep scene and template parents within 60 children', () => {
  const root = battleLayout();
  function visit(controls) {
    assert.ok(controls.length <= 60);
    assert.equal(new Set(controls.map(c => c.name)).size, controls.length);
    for (const control of controls) visit(control.children ?? []);
  }
  visit(root.controls);
  const stage = root.controls.find(c => c.name === 'stage');
  const actorLayer = stage.children.find(c => c.name === 'actorLayer');
  assert.equal(actorLayer?.kind, 'container', 'runtime actors need a real native container');
  assert.deepEqual(actorLayer.size, theme.canvas.base);
  assert.deepEqual(actorLayer.children, [], 'actor instances belong to the runtime manager');
  assert.ok(!stage.children.some(c => /^enemy\d+$/.test(c.name)), 'scene must not reserve a fixed enemy-slot ceiling');
  const actor = enemyUnitTemplate(), power = enemyPowerTemplate();
  visit([actor, power]);
  for (const name of ['hit', 'intentHit']) {
    assert.equal(actor.children.find(c => c.name === name)?.kind, 'cursorArea', `${name} remains a native actor-owned entry`);
  }
  assert.equal(power.children.find(c => c.name === 'hit')?.kind, 'cursorArea', 'runtime power details retain their own native entry');
  for (const name of ['drawIcon', 'draw', 'drawLabel', 'discardIcon', 'discard', 'discardLabel', 'exhaustIcon', 'exhaust']) {
    assert.ok(stage.children.find(c => c.name === name), name);
  }
});
