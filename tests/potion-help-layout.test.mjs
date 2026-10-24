import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

test('each battle bottle has a separate discoverable explanation target within the safe area', () => {
  const battle = gameLayout().controls.find(c => c.name === 'battlePanel');
  const help = battle.children.find(c => c.name === 'potionHelp');
  assert.equal(help.children.length, 3);
  const overlaps = (a, b) => a.position.every((p, i) => Math.abs(p - b.position[i]) < (a.size[i] + b.size[i]) / 2);
  const controls = [...help.children, ...battle.children.filter(c => /^potion\d$/.test(c.name))];
  const notice = battle.children.find(c => c.name === 'notice');
  for (const [i, c] of controls.entries()) {
    assert.ok(c.size.every(n => n >= 44), c.name);
    for (const [axis, n] of c.position.entries()) assert.ok(Math.abs(n) + c.size[axis] / 2 <= theme.canvas.base[axis] / 2 - (axis ? theme.canvas.safe.y : theme.canvas.safe.x), c.name);
    assert.ok(!overlaps(c, notice), `${c.name} overlaps aiming instructions`);
    for (const other of controls.slice(i + 1)) assert.ok(!overlaps(c, other), `${c.name} overlaps ${other.name}`);
  }
  for (const c of controls) for (const state of c.children) {
    const label = state.children.find(c => c.name === 'label');
    if (c.name.startsWith('potionHelp')) assert.equal(label.text.content, '说明');
    assert.ok(label.size[1] >= theme.layout.nativeText.lineHeight);
  }
});
