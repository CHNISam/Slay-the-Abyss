import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { deckCardTemplate } from '../scripts/deck-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

function walk(control, fn) { fn(control); for (const child of control.children ?? []) walk(child, fn); }
test('approved deck uses a six-column vertical native scroller and a read-only reusable card template', () => {
  const panel = gameLayout().controls.find(c => c.name === 'deckPanel');
  const grid = panel.children.find(c => c.name === 'grid');
  assert.equal(panel.visible, false);
  const veil = panel.children.find(c => c.name === 'veil');
  assert.equal(veil.colour, theme.color.backdropVeil.slice(0, 7));
  assert.equal(veil.opacity, 0.8);
  assert.equal(grid.kind, 'grid');
  assert.equal(grid.itemTemplate, deckCardTemplate().name);
  assert.equal(grid.grid.columns, 6);
  assert.equal(grid.grid.scrollbar, true);
  assert.equal(grid.grid.horizontal, false);
  assert.deepEqual(grid.size, [1120, 560]);
  assert.equal(panel.children.find(c => c.name === 'blocker').kind, 'cursorArea');
  const template = deckCardTemplate();
  walk(template, c => {
    if(c.name==='hit'){
      assert.equal(c.kind,'cursorArea','choices need a native cursor receiver');
      assert.equal(c.visible,false,'read-only cards cannot steal scroll gestures');
      assert.deepEqual(c.size,theme.layout.card.size);
    }else assert.ok(!['cursorArea','presetButton'].includes(c.kind),'only the hidden choice receiver may handle input');
    assert.ok((c.children?.length ?? 0) <= 60);
  });
  assert.ok(template.children.find(c => c.name === 'uid'));
  const face = template.children.find(c => c.name === 'face');
  assert.deepEqual(face.size, theme.layout.card.size);
  assert.deepEqual(face.children.find(c => c.name === 'label').size, theme.layout.card.textBox);
  const [top, bottom, left, right] = grid.grid.padding;
  assert.ok(left + 6 * grid.grid.itemSize[0] + 5 * grid.grid.spacing[0] + right <= grid.size[0]);
  assert.ok(top + grid.grid.itemSize[1] + bottom <= grid.size[1]);
  for (const name of ['open', 'close']) {
    const wrapper = name === 'open' ? gameLayout().controls.find(c => c.name === 'deckEntry').children[0]
      : panel.children.find(c => c.name === name);
    const hit = wrapper.children.find(c => c.name === 'hit');
    assert.equal(hit.kind, 'presetButton');
    for (const state of ['normal', 'hover', 'pressed', 'disabled']) assert.ok(hit.children.find(c => c.name === hit.states[state]));
    assert.deepEqual(hit.children.find(c => c.name === 'pressed').scale, [0.96, 0.96]);
  }
});

test('deck overlay and close remain inside approved canvas safe areas at every device scale', () => {
  const layout = gameLayout();
  for (const control of layout.controls) walk(control, c => assert.ok((c.children?.length ?? 0) <= 60, c.name));
  for (const device of Object.values(theme.canvas.devices)) {
    const k = Math.min(device[0] / theme.canvas.base[0], device[1] / theme.canvas.base[1]);
    const panel = layout.controls.find(c => c.name === 'deckPanel');
    for (const c of ['close','grid','previous','next','pageHint'].map(name => panel.children.find(c => c.name === name)).concat([
      layout.controls.find(c => c.name === 'deckEntry').children.find(c => c.name === 'open')])) {
      assert.ok((Math.abs(c.position[0]) + c.size[0] / 2 + theme.canvas.safe.x) * k <= device[0] / 2);
      assert.ok((Math.abs(c.position[1]) + c.size[1] / 2 + theme.canvas.safe.y) * k <= device[1] / 2);
    }
  }
});

test('controller overlays isolate nearest-control navigation and deck pages leave the card viewport clear', () => {
  const layout = gameLayout(undefined, {originalCharacters: true});
  for (const name of ['deckPanel','potionPanel','choicePanel','characterPanel','exitPanel']) {
    assert.equal(layout.controls.find(c => c.name === name).isolateNavigation, true, name);
  }
  const deck = layout.controls.find(c => c.name === 'deckPanel');
  const grid = deck.children.find(c => c.name === 'grid');
  for (const name of ['previous','next','pageHint']) {
    const control = deck.children.find(c => c.name === name);
    assert.equal(control.visible, false, 'controller-only paging starts hidden');
    assert.ok(control.position[1] + control.size[1] / 2 < grid.position[1] - grid.size[1] / 2);
  }
});
