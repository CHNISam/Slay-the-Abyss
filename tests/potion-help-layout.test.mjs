import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

test('five source bottle slots share an explicit effect card and retain hidden compatibility explanation paths', () => {
  const battle = gameLayout().controls.find(c => c.name === 'battlePanel');
  const help = battle.children.find(c => c.name === 'potionHelp');
  const buttons = help.children.filter(c => /^potionHelp\d$/.test(c.name));
  assert.equal(buttons.length, 5);
  const relics = help.children.filter(c => /^relicReward[12]$/.test(c.name));
  assert.deepEqual(relics.map(c => c.name), ['relicReward1', 'relicReward2']);
  const emerald = help.children.find(c => c.name === 'emeraldKeyReward');
  assert.ok(emerald, 'independent Emerald key reward must be discoverable');
  assert.equal(emerald.kind, 'presetButton');
  assert.equal(emerald.focusable, true);
  const original = help.children.filter(c => !/^relicReward[12]$|^emeraldKeyReward$/.test(c.name));
  assert.equal(original.length, 9);
  assert.equal(help.children.length, 12);
  assert.deepEqual(original.map(c => c.name), ['potionHelp1', 'potionHelp2', 'potionHelp3', 'potion4', 'potionHelp4', 'potion5', 'potionHelp5', 'potionPopup', 'potionReward']);
  for (const relic of [...relics, emerald]) {
    assert.equal(relic.visible, false, 'elite rewards start hidden during combat');
    assert.deepEqual(relic.position, theme.layout.battleRewards.rowOrigin);
    assert.deepEqual(relic.size, theme.layout.battleRewards.rowSize);
    assert.ok(relic.size.every(n => n >= 44), relic.name);
    assert.deepEqual(relic.children.map(c => c.name), ['normal', 'hover', 'pressed', 'disabled']);
    for (const state of relic.children) {
      const label = state.children.find(c => c.name === 'label');
      assert.equal(label.text.content, relic === emerald ? '领取绿钥匙' : '遗物');
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
  const controls = [...battle.children, ...help.children].filter(c => /^potion\d$/.test(c.name));
  assert.equal(controls.length, 5);
  for(const c of buttons)assert.equal(c.visible,false,'old second explanation row is no longer an input target');
  const popup=help.children.find(c=>c.name==='potionPopup');assert.equal(popup.visible,false);
  for(const name of ['effect','use','discard','dismiss'])assert(popup.children.some(c=>c.name===name));
  const notice = battle.children.find(c => c.name === 'notice');
  for (const [i, c] of controls.entries()) {
    assert.deepEqual(c.size,[44,44],c.name+' readable touch target');
    for (const [axis, n] of c.position.entries()) assert.ok(Math.abs(n) + c.size[axis] / 2 <= theme.canvas.base[axis] / 2, c.name);
    assert.ok(!overlaps(c, notice), `${c.name} overlaps aiming instructions`);
    for (const other of controls.slice(i + 1)) assert.ok(!overlaps(c, other), `${c.name} overlaps ${other.name}`);
  }
  for (const c of controls) for (const state of c.children) {
    const label = state.children.find(c => c.name === 'label');
    assert.equal(label.visible,false,'source bottle has no text row');
    const bottle=state.children.find(c=>c.name==='bottle');assert.ok(bottle);
    assert.equal(bottle.image,theme.icon.potion.fire_potion);
  }
});
