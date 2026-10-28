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
