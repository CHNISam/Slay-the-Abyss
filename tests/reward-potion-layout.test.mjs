import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, theme } from '../scripts/ui-layout.mjs';

const bounds = (position, size) => ({left: position[0] - size[0] / 2, right: position[0] + size[0] / 2,
  bottom: position[1] - size[1] / 2, top: position[1] + size[1] / 2});
const overlaps = (a, b) => a.left < b.right && a.right > b.left && a.bottom < b.top && a.top > b.bottom;

test('centered card reward preserves separate potion controls and a readable bottom label', () => {
  const controls = battleLayout().controls.find(control => control.name === 'stage').children;
  const pick = theme.layout.rewardPick;
  const utilityNames = ['skip', 'claimPotion', 'skipPotion', 'potionReward'];
  const utilities = utilityNames.map(name => {
    const control = controls.find(control => control.name === name);
    assert.ok(control, name);
    return {name, box: bounds(control.position, control.size)};
  });
  for (const {name, box} of utilities) {
    assert.ok(box.left >= -theme.canvas.base[0] / 2 + theme.canvas.safe.x &&
      box.right <= theme.canvas.base[0] / 2 - theme.canvas.safe.x &&
      box.bottom >= -theme.canvas.base[1] / 2 + theme.canvas.safe.y &&
      box.top <= theme.canvas.base[1] / 2 - theme.canvas.safe.y, `${name}: safe area`);
  }
  for (let i = 0; i < utilities.length; i++) for (let j = i + 1; j < utilities.length; j++) {
    assert.ok(!overlaps(utilities[i].box, utilities[j].box), `${utilities[i].name} overlaps ${utilities[j].name}`);
  }
  // Conservative envelope includes all three cards' largest hover scale and
  // full entrance drop, rather than checking only their settled rectangles.
  const cardSize = theme.layout.card.size.map(value => value * pick.hoverScale);
  for (const x of [-pick.step, 0, pick.step]) {
    const envelope = bounds([x, pick.y - pick.enterRise], [cardSize[0], cardSize[1] + pick.hoverLift * 2]);
    for (const {name, box} of utilities) assert.ok(!overlaps(box, envelope), `${name} overlaps reward card motion`);
  }
  const stage = controls.find(control => control.name === 'rewardStage');
  for (const name of ['title', 'subtitle']) {
    const label = stage.children.find(control => control.name === name);
    const box = bounds(label.position.map((value, index) => value + stage.position[index]), label.size);
    for (const utility of utilities) assert.ok(!overlaps(box, utility.box), `${utility.name} overlaps ${name}`);
  }
  assert.deepEqual(controls.find(control => control.name === 'claimPotion').position, [-pick.step, pick.skip[1]]);
  assert.deepEqual(controls.find(control => control.name === 'skipPotion').position, [pick.step, pick.skip[1]]);
});
