import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, theme } from '../scripts/ui-layout.mjs';

const bounds = (position, size) => ({left: position[0] - size[0] / 2, right: position[0] + size[0] / 2,
  bottom: position[1] - size[1] / 2, top: position[1] + size[1] / 2});
const overlaps = (a, b) => a.left < b.right && a.right > b.left && a.bottom < b.top && a.top > b.bottom;

test('reward list has four safe rows above Proceed and separate native-height feedback', () => {
  const controls = battleLayout().controls.find(control => control.name === 'stage').children;
  const list = theme.layout.battleRewards;
  const boxes = [list.title, list.subtitle].map(frame => bounds(frame.slice(0, 2), frame.slice(2)));
  for (let row = 0; row < 4; row++) boxes.push(bounds([list.rowOrigin[0], list.rowOrigin[1] - row * list.rowStep], list.rowSize));
  boxes.push(bounds(list.continue.slice(0, 2), list.continue.slice(2)), bounds(list.potionLabel.slice(0, 2), list.potionLabel.slice(2)));
  for (const box of boxes) assert.ok(box.left >= -theme.canvas.base[0] / 2 + theme.canvas.safe.x &&
    box.right <= theme.canvas.base[0] / 2 - theme.canvas.safe.x && box.bottom >= -theme.canvas.base[1] / 2 + theme.canvas.safe.y &&
    box.top <= theme.canvas.base[1] / 2 - theme.canvas.safe.y);
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) assert.ok(!overlaps(boxes[i], boxes[j]), `${i} overlaps ${j}`);
  for (const name of ['goldReward', 'cardReward', 'claimPotion', 'stolenGold']) {
    assert.deepEqual(controls.find(control => control.name === name).size, list.rowSize);
  }
  assert.deepEqual(controls.find(control => control.name === 'continue').size, list.continue.slice(2));
});
