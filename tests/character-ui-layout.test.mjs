import test from 'node:test';
import assert from 'node:assert/strict';
import { experimentalCharacterControls } from '../scripts/character-ui-layout.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';

test('formal character and card choices are present with either legacy flag', () => {
  const normal = gameLayout(), experimental = gameLayout(nativeTheme, { experimentalCharacters: true });
  assert.equal(normal.controls.filter(c => ['characterPanel', 'choicePanel'].includes(c.name)).length, 2);
  assert.deepEqual(normal, experimental);
  const panel = normal.controls.find(c => c.name === 'characterPanel');
  for (const name of ['character1','character2','character3','character4','traveler','confirm','details','elements']) assert.ok(panel.children.find(c => c.name === name), name);
  const details = panel.children.find(c => c.name === 'details');
  // TASK-59.3.1：选角页不提供牌组筛选按钮；信息层级为 名字→生命/金币→遗物→牌组。
  assert.equal(details.children.filter(c => /^deckFilter/.test(c.name)).length, 0);
  const at = name => { const c = details.children.find(x => x.name === name); assert.ok(c, name); return c; };
  const ys = ['name', 'stats', 'relic', 'relicText', 'deckTitle', 'card1'].map(n => at(n).position[1]);
  for (let i = 1; i < ys.length; i++) assert.ok(ys[i] < ys[i - 1], 'information hierarchy runs top-down');
  assert.equal(at('stats').position[1], at('gold').position[1], 'HP and gold share one scannable row');
  const frame = at('portraitFrame');
  assert.equal(frame.kind, 'container', 'portrait sits on the floor glow, not inside a dark rectangle');
  assert.equal(frame.size[0], frame.size[1], 'portrait slot matches the square figure/art aspect');
  const themes = panel.children.find(c => c.name === 'themes');
  for (const layer of themes.children) for (const glow of layer.children) assert.notEqual(glow.image, nativeTheme.image.ring);
  for (const name of ['character1', 'traveler']) {
    const face = panel.children.find(c => c.name === name).children.find(c => c.name === 'hit').children[0];
    const bust = face.children.find(c => c.name === 'bust'), well = face.children.find(c => c.name === 'well');
    const label = face.children.find(c => c.name === 'label'), size = panel.children.find(c => c.name === name).size;
    assert.ok(bust.size[0] >= 64, 'avatar fills its card');
    assert.ok(Math.abs(bust.position[1]) + bust.size[1] / 2 <= size[1] / 2, 'avatar is not cut by its card');
    assert.ok(bust.position[1] - bust.size[1] / 2 >= label.position[1] + label.size[1] / 2 - 1, 'name plate does not cover the face');
    assert.deepEqual(well.position, bust.position);
  }
  assert.equal(experimental.controls.filter(c => ['characterPanel', 'choicePanel'].includes(c.name)).length, 2);
  assertNativeUiCapacity(experimental);
});

test('choice controls preserve the theme, four button states, and touch safe area', () => {
  const panels = experimentalCharacterControls();
  for (const panel of panels) {
    assert.equal(panel.visible, false);
    assert.ok(panel.children.find(c => c.name === 'blocker'));
    for (const button of panel.children.filter(c => c.children?.some(k => k.kind === 'presetButton'))) {
      const hit = button.children.find(c => c.name === 'hit');
      assert.deepEqual(Object.keys(hit.states), ['normal', 'hover', 'pressed', 'disabled']);
      assert.ok(button.size[0] >= 44 && button.size[1] >= 44);
      assert.ok(Math.abs(button.position[0]) + button.size[0] / 2 <= 600);
      assert.ok(Math.abs(button.position[1]) + button.size[1] / 2 <= 340);
      for (const variant of hit.children) {
        const label = variant.children.find(c => c.name === 'label');
        assert.ok(label.text.fontSize >= nativeTheme.font.minimum);
      }
    }
  }
  assert.equal(panels[1].children.filter(c => /^card\d+$/.test(c.name)).length, 10);
});
