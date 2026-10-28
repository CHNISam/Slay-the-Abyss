import test from 'node:test';
import assert from 'node:assert/strict';
import { battleLayout, handPose, theme } from '../scripts/ui-layout.mjs';

const stage = () => battleLayout().controls.find(c => c.name === 'stage');
test('feedback uses a fixed non-interactive native pool within the per-parent platform limit', () => {
  walk(battleLayout().controls, control => assert.ok((control.children?.length ?? 0) <= 60, control.name));
  const actors = stage().children.filter(c => c.name === 'hero' || /^enemy\d+$/.test(c.name));
  assert.equal(actors.length, 6);
  for (const actor of actors) for (const name of ['hpGhost', 'impact', 'shield', 'floating']) {
    const pool = actor.children.filter(c => c.name === name);
    assert.equal(pool.length, 1);
    assert.equal(pool[0].kind === 'cursorArea', false);
    if (name !== 'hpGhost') assert.equal(pool[0].visible, false);
  }
  const overlay = stage().children.find(c => c.name === 'feedback');
  walk([overlay], control => assert.ok(!['cursorArea', 'presetButton'].includes(control.kind)));
  // Polish adds exactly one shared area sweep; every other effect reuses the per-actor pool.
  const sweep = overlay.children.filter(c => c.name === 'sweep');
  assert.equal(sweep.length, 1);
  assert.equal(sweep[0].visible, false);
  assert.equal(sweep[0].image, theme.image.diamond);
  assert.equal(overlay.children.length, 4);
});
test('every actor has a status chip grid within platform limits and a portrait detail hit', () => {
  const si = theme.layout.statusIcon;
  for (const unit of stage().children.filter(c => c.name === 'hero' || /^enemy\d+$/.test(c.name))) {
    const row = unit.children.find(c => c.name === 'statusRow');
    assert.equal(row.children.filter(c => /^icon\d+$/.test(c.name)).length, si.perRow * si.rows);
    assert.equal(row.children.filter(c => /^count\d+$/.test(c.name)).length, si.perRow * si.rows);
    assert.equal(row.children.at(-1).kind, 'cursorArea', `${unit.name} status hit sits above its chips`);
    // Decorative status plates are grouped to stay below the platform's child
    // limit; each image/text leaf must still start hidden.
    walk(row.children, chip => {
      if (!['cursorArea', 'container'].includes(chip.kind)) assert.equal(chip.visible, false);
    });
    assert(unit.children.some(c => c.name === 'hit' && c.kind === 'cursorArea'), `${unit.name} portrait hit`);
  }
  const info = stage().children.find(c => c.name === 'statusInfo');
  for (let i = 1; i <= theme.layout.statusInfo.rows; i++) {
    for (const name of [`icon${i}`, `name${i}`, `tag${i}`, `text${i}`, `note${i}`]) assert(info.children.some(c => c.name === name), name);
  }
  assert(info.children.length <= 60);
});
test('approved critical actor values and card types have native text line room', () => {
  const controls = stage().children;
  for (const unit of controls.filter(c => c.name === 'hero' || /^enemy\d+$/.test(c.name))) {
    for (const name of ['name', 'hp', 'block']) {
      const label = unit.children.find(c => c.name === name);
      assert(label && label.size[1] >= theme.layout.nativeText.lineHeight, `${unit.name}/${name}`);
      assert(label.text.minFontSize >= theme.font.minimum);
    }
  }
  for (const card of controls.filter(c => /^card\d+$/.test(c.name))) {
    assert(card.children.find(c => c.name === 'type').size[1] >= theme.layout.nativeText.lineHeight);
  }
});

test('all dynamic battle numbers retain a native text line without intercepting input', () => {
  const controls = stage().children;
  const numbers = controls.filter(c => ['player', 'piles', 'exhaust', 'energy', 'draw', 'discard'].includes(c.name))
    .map(control => ({ path: control.name, control }));
  for (const actor of controls.filter(c => c.name === 'hero' || /^enemy\d+$/.test(c.name))) {
    for (const control of actor.children.filter(c => ['hp', 'block', 'intent'].includes(c.name))) {
      numbers.push({ path: `${actor.name}/${control.name}`, control });
    }
    const row = actor.children.find(c => c.name === 'statusRow');
    for (const control of row.children.filter(c => /^count\d+$/.test(c.name))) {
      numbers.push({ path: `${actor.name}/statusRow/${control.name}`, control });
    }
  }
  for (const card of controls.filter(c => /^card\d+$/.test(c.name))) {
    numbers.push({ path: `${card.name}/cost`, control: card.children.find(c => c.name === 'cost') });
  }
  // These are the controller's numeric fields, including hidden slots populated
  // by live state. autoSize cannot rescue a native box shorter than one line.
  assert(numbers.some(({ path }) => path === 'draw'));
  assert(numbers.some(({ path }) => path === 'discard'));
  assert(numbers.some(({ path }) => path === 'enemy5/statusRow/count10'));
  const tooShort = [];
  for (const { path, control } of numbers) {
    assert.equal(control?.kind, 'text', path);
    assert.notEqual(control.focusable, true, `${path} must not take pointer focus`);
    assert(control.text.minFontSize >= theme.font.minimum, path);
    if (control.size[1] < theme.layout.nativeText.lineHeight) tooShort.push(path);
  }
  assert.deepEqual(tooShort, [], 'dynamic numbers need a complete native text line');
});

test('status detail card renders every line natively, left-aligned, and a full page fits under the top bar', () => {
  // A native text box shorter than one line height renders nothing: the panel
  // once showed only an icon and a single truncated description line. Boxes keep
  // the full line height and overlap; Lua spaces them by the smaller pitch.
  const line = theme.layout.nativeText.lineHeight, si = theme.layout.statusInfo, s = theme.space;
  const info = stage().children.find(c => c.name === 'statusInfo');
  const texts = info.children.filter(c => c.kind === 'text');
  for (const box of texts) assert(box.size[1] >= line, box.name);
  for (const box of texts.filter(c => /^(title|summary|guard|section\d|name\d|text\d|note\d)$/.test(c.name))) {
    assert.equal(box.text.align, 'left', `${box.name} reads from the left edge`);
  }
  for (const box of texts.filter(c => /^tag\d?$/.test(c.name))) assert.equal(box.text.align, 'right', box.name);
  // The card's own hit sits above every row so a tap turns the page, never the stage.
  assert.equal(info.children.at(-1).name, 'page');
  assert.equal(info.children.at(-1).kind, 'cursorArea');
  const [, height] = theme.canvas.base;
  const room = height - theme.layout.topBar.height - s.s - theme.canvas.safe.y;
  const fixed = si.pad * 2 + si.header + si.summary + si.divider + si.footer;
  const row = si.name + si.line * 2 + si.entryGap; // effect + condition, one line each
  assert(fixed + si.sections * si.section + si.rows * row <= room, 'a full page fits on screen');
});
function walk(controls, fn, x = 0, y = 0) {
  const names = new Set();
  for (const control of controls) {
    assert(!names.has(control.name)); names.add(control.name);
    const cx = x + (control.position?.[0] || 0), cy = y + (control.position?.[1] || 0);
    fn(control, cx, cy);
    if (control.children) walk(control.children, fn, cx, cy);
  }
}
test('the shared theme drives a centered stage with a canvas-filling backdrop outside it', () => {
  const tree = battleLayout();
  assert.deepEqual(stage().size, theme.canvas.base);
  assert.deepEqual(tree.controls[0].anchor, {min: [0.5, 0.5], max: [0.5, 0.5]});
  assert.equal(tree.controls[0].colour, theme.color.backdrop);
  assert.equal(tree.showCursor, true);
  assert.equal(tree.blockCursor, true);
  walk(stage().children, (c, x, y) => {
    // Rotated cards are checked separately, including runtime selected poses.
    if (!/^card\d+$/.test(c.name)) {
      assert(Math.abs(x) + c.size[0] / 2 <= 640, c.name + ' horizontal');
      assert(Math.abs(y) + c.size[1] / 2 <= 360, c.name + ' vertical');
    }
    if (c.text) assert(c.text.minFontSize >= theme.font.minimum, c.name);
  });
});
test('one through ten hand cards, including selection, fit the 40/20 safe area on every canvas', () => {
  for (const [width, height] of [...Object.values(theme.canvas.devices), [1560, 720]]) {
    const k = Math.min(width / 1280, height / 720);
    for (let count = 1; count <= 10; count++) for (let i = 0; i < count; i++) for (const selected of [false, true]) {
      const pose = handPose(count, i, selected);
      const [w, h] = theme.layout.card.size.map(n => n * pose.scale[0]);
      const radians = Math.abs(pose.rotation) * Math.PI / 180;
      const halfW = (w * Math.cos(radians) + h * Math.sin(radians)) / 2;
      const halfH = (h * Math.cos(radians) + w * Math.sin(radians)) / 2;
      assert((Math.abs(pose.position[0]) + halfW) * k <= width / 2 - 40 * k + 1e-8);
      assert((Math.abs(pose.position[1]) + halfH) * k <= height / 2 - 20 * k + 1e-8, `${count}/${i}/${selected} vertical`);
      if (i > 0) assert(pose.position[0] - handPose(count, i - 1, selected).position[0] >= 44);
    }
  }
});
test('native buttons provide all four states and touch hit areas stay inside the safe area', () => {
  const controls = stage().children;
  const drag = controls.find(c => c.name === 'dragLayer');
  const capture = drag.children.find(c => c.name === 'hit');
  assert.equal(drag.visible, false);
  assert.equal(capture.focusable, false);
  assert.deepEqual(capture.size, theme.canvas.base);
  // The status detail panel dismisses on any tap through its own hidden full-canvas catcher.
  const info = controls.find(c => c.name === 'statusInfo');
  const dismiss = info.children.find(c => c.name === 'hit');
  assert.equal(info.visible, false);
  assert.equal(dismiss.focusable, false);
  assert.deepEqual(dismiss.size, theme.canvas.base);
  assert.equal(controls.filter(c => /^card\d+$/.test(c.name)).length, 10);
  walk(controls, (c, x, y) => {
    if (c.kind === 'presetButton') {
      for (const state of ['normal', 'hover', 'pressed', 'disabled']) {
        assert(c.children.some(child => child.name === c.states[state]));
      }
      assert.deepEqual(c.children.find(child => child.name === 'pressed').scale, [0.96, 0.96]);
    }
    if (c.kind === 'cursorArea' || c.kind === 'presetButton') {
      assert(Math.min(...c.size) >= 44);
      if (c === capture || c === dismiss) return; // invisible catchers cover the canvas, ordinary touch controls stay safe
      assert(Math.abs(x) + c.size[0] / 2 <= 600 + 1e-8, c.name + ' safe x');
      assert(Math.abs(y) + c.size[1] / 2 <= 340 + 1e-8, c.name + ' safe y');
    }
    if (c.name === 'hpFill') { assert.equal(c.mask, true); assert.equal(c.fill.shape, 'horizontal'); }
  });
});

test('five potion buttons follow shared tokens and clear the HUD, notice, hand and turn controls', () => {
  const controls = stage().children;
  const potions = [...controls, ...controls.find(c=>c.name==='potionHelp').children].filter(control => /^potion\d+$/.test(control.name));
  assert.equal(potions.length, 5);
  const notice = controls.find(control => control.name === 'notice');
  assert.deepEqual(notice.position, theme.layout.battleNotice.position);
  assert.deepEqual(notice.size, theme.layout.battleNotice.size);
  function overlaps(a, b) {
    return Math.abs(a.position[0] - b.position[0]) < (a.size[0] + b.size[0]) / 2
      && Math.abs(a.position[1] - b.position[1]) < (a.size[1] + b.size[1]) / 2;
  }
  for (const [i, potion] of potions.entries()) {
    assert.deepEqual(potion.position, theme.layout.battlePotions.origin.map((n, axis) => n + theme.layout.battlePotions.step[axis] * i));
    assert.deepEqual(potion.size, theme.layout.battlePotions.size);
    assert.equal(potion.kind, 'presetButton');
    for (const state of potion.children) {
      const label = state.children.find(control => control.name === 'label');
      assert.equal(label.text.fontSize, theme.font.small);
      assert(label.size[1] >= theme.font.small * 2, `${potion.name} keeps two readable lines`);
    }
    for (const name of ['title', 'player', 'piles', 'notice', 'energyDisc', 'endTurn']) {
      assert(!overlaps(potion, controls.find(control => control.name === name)), `${potion.name}/${name}`);
    }
    for (const other of potions) if (other !== potion) assert(!overlaps(potion, other));
    for (let count = 1; count <= 10; count++) for (let index = 0; index < count; index++) for (const selected of [false, true]) {
      const pose = handPose(count, index, selected);
      const [width, height] = theme.layout.card.size.map(n => n * pose.scale[0]);
      const radians = Math.abs(pose.rotation) * Math.PI / 180;
      assert(!overlaps(potion, {position: pose.position, size: [width * Math.cos(radians) + height * Math.sin(radians),
        height * Math.cos(radians) + width * Math.sin(radians)]}));
    }
  }
});
