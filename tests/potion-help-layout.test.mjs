import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

test('each battle bottle has a separate discoverable explanation target within the safe area', () => {
  const battle = gameLayout().controls.find(c => c.name === 'battlePanel');
  const help = battle.children.find(c => c.name === 'potionHelp');
  const buttons = help.children.filter(c => /^potionHelp\d$/.test(c.name));
  assert.equal(buttons.length, 5);
  const relics = help.children.filter(c => /^relicReward[12]$/.test(c.name));
  assert.deepEqual(relics.map(c => c.name), ['relicReward1', 'relicReward2']);
  const original = help.children.filter(c => !/^relicReward[12]$/.test(c.name));
  assert.equal(original.length, 8);
  assert.equal(help.children.length, 10);
  assert.deepEqual(original.map(c => c.name), ['potionHelp1', 'potionHelp2', 'potionHelp3', 'potion4', 'potionHelp4', 'potion5', 'potionHelp5', 'potionReward']);
  for (const relic of relics) {
    assert.equal(relic.visible, false, 'elite rewards start hidden during combat');
    assert.deepEqual(relic.position, theme.layout.battleRewards.rowOrigin);
    assert.deepEqual(relic.size, theme.layout.battleRewards.rowSize);
    assert.ok(relic.size.every(n => n >= 44), relic.name);
    assert.deepEqual(relic.children.map(c => c.name), ['normal', 'hover', 'pressed', 'disabled']);
    for (const state of relic.children) {
      const label = state.children.find(c => c.name === 'label');
      assert.equal(label.text.content, '遗物');
      assert.ok(label.size[1] >= theme.layout.nativeText.lineHeight);
    }
  }
  const note = help.children.find(c => c.name === 'potionReward');
  assert.equal(note.kind, 'text');
  assert.deepEqual(help.position ?? [0, 0], [0, 0]);
  assert.deepEqual(help.size, theme.canvas.base);
  assert.deepEqual(note.position, theme.layout.battleRewards.potionLabel.slice(0, 2));
  assert.deepEqual(note.size, theme.layout.battleRewards.potionLabel.slice(2));
  const overlaps = (a, b) => a.position.every((p, i) => Math.abs(p - b.position[i]) < (a.size[i] + b.size[i]) / 2);
  const controls = [...buttons, ...[...battle.children, ...help.children].filter(c => /^potion\d$/.test(c.name))];
  assert.equal(controls.length, 10);
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
