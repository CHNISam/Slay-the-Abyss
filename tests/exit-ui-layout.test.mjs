import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

const named = (controls, name) => controls.find(control => control.name === name);
const child = (control, name) => named(control.children, name);
function descendant(control, name) {
  if (control.name === name) return control;
  for (const c of control.children ?? []) {
    const found = descendant(c, name);
    if (found) return found;
  }
}
function walk(control, fn) { fn(control); for (const c of control.children ?? []) walk(c, fn); }
function overlaps(a, b) {
  return a.position.every((position, i) => Math.abs(position - b.position[i]) < (a.size[i] + b.size[i]) / 2);
}

test('exit remains above every game page and the deck, with a separate blocking confirmation', () => {
  const controls = gameLayout().controls;
  const entry = named(controls, 'exitEntry'), panel = named(controls, 'exitPanel');
  assert.ok(entry, 'every page needs the shared exit entry');
  assert.ok(panel, 'exit requires an explicit confirmation');
  assert.notEqual(entry.visible, false);
  assert.equal(panel.visible, false);
  assert.ok(controls.indexOf(entry) > controls.indexOf(named(controls, 'deckPanel')));
  assert.ok(controls.indexOf(panel) > controls.indexOf(entry));
  assert.equal(child(panel, 'blocker').kind, 'cursorArea');
  assert.deepEqual(child(panel, 'blocker').size, theme.canvas.base);
  for (const name of ['title', 'message', 'status']) assert.equal(child(panel, name).kind, 'text');
  for (const [button, label] of [[child(entry, 'open'), '菜单'], [child(panel, 'cancel'), '继续游戏'],
    [child(panel, 'confirm'), '退出并结算']]) {
    const hit = child(button, 'hit');
    assert.equal(hit.kind, 'presetButton');
    assert.ok(button.size[0] >= 48 && button.size[1] >= 48);
    for (const state of ['normal', 'hover', 'pressed', 'disabled']) {
      const variant = child(hit, hit.states[state]);
      assert.ok(variant, `native ${state} state must stay visible`);
      assert.equal(child(variant, 'label').text.content, label);
      assert.ok(child(variant, 'label').size[1] >= 40);
    }
    assert.deepEqual(child(hit, 'pressed').scale,
      [theme.layout.exitMenu.pressedScale, theme.layout.exitMenu.pressedScale]);
  }
  assert.ok(panel.children.indexOf(child(panel, 'blocker')) < panel.children.indexOf(child(panel, 'cancel')));
});

test('exit entry does not cover deck controls, map navigation or the narrowed game notices', () => {
  const controls = gameLayout().controls;
  const entry = child(named(controls, 'exitEntry'), 'open');
  for (const obstacle of [child(named(controls, 'deckEntry'), 'open'),
    child(named(controls, 'deckPanel'), 'close'), descendant(named(controls, 'mapPanel'), 'next'),
    child(named(controls, 'battlePanel'), 'notice'), child(named(controls, 'nodePanel'), 'notice')]) {
    assert.ok(!overlaps(entry, obstacle), `exit overlaps ${obstacle.name}`);
  }
  // Main's approved short operation strip replaces the former wide upper notice.
  const battleNotice=child(named(controls,'battlePanel'),'notice');
  assert.deepEqual(battleNotice.size,[880,40]);
  assert.deepEqual(battleNotice.position,[0,360-(700+52/2)/1.5]);
  assert.deepEqual(battleNotice.size,theme.layout.battleNotice.size);
  assert.ok(child(named(controls, 'nodePanel'), 'notice').size[0] >= 900);
});

test('exit geometry follows theme and safe device scaling without oversized containers', () => {
  const controls = gameLayout().controls;
  for (const c of controls) walk(c, item => assert.ok((item.children?.length ?? 0) <= 60, item.name));
  const entry = child(named(controls, 'exitEntry'), 'open'), panel = named(controls, 'exitPanel');
  for (const device of [...Object.values(theme.canvas.devices), [1560, 720]]) {
    const scale = Math.min(device[0] / theme.canvas.base[0], device[1] / theme.canvas.base[1]);
    for (const c of [entry, ...['title', 'message', 'status', 'cancel', 'confirm'].map(name => child(panel, name))]) {
      for (const [i, margin] of [theme.canvas.safe.x, theme.canvas.safe.y].entries()) {
        assert.ok((Math.abs(c.position[i]) + c.size[i] / 2 + margin) * scale <= device[i] / 2,
          `${c.name} exceeds device ${device}`);
      }
    }
  }
  const changed = structuredClone(theme);
  changed.layout.exitMenu.entry[0] -= 20;
  changed.layout.exitMenu.confirm[0] -= 10;
  const custom = gameLayout(changed).controls;
  assert.deepEqual(child(named(custom, 'exitEntry'), 'open').position, changed.layout.exitMenu.entry.slice(0, 2));
  assert.deepEqual(child(named(custom, 'exitPanel'), 'confirm').position, changed.layout.exitMenu.confirm.slice(0, 2));
});

test('TASK-4.11 exit warning hierarchy: header, consequence, note, status and actions never overlap', () => {
  const panel = named(gameLayout().controls, 'exitPanel');
  const frame = name => child(panel, name);
  const box = c => ({ l: c.position[0] - c.size[0] / 2, r: c.position[0] + c.size[0] / 2,
    b: c.position[1] - c.size[1] / 2, t: c.position[1] + c.size[1] / 2 });
  const hit = (a, b) => { const A = box(a), B = box(b); return A.l < B.r && B.l < A.r && A.b < B.t && B.b < A.t; };
  const order = ['title', 'help', 'rule', 'message', 'whyText', 'status', 'cancel', 'confirm'];
  for (const a of order) for (const b of order) if (a !== b) assert.ok(!hit(frame(a), frame(b)), `${a} overlaps ${b}`);
  // Reading order top → bottom: header above rule above consequence above note above status above actions.
  const y = n => frame(n).position[1];
  assert.ok(y('help') > y('rule') && y('rule') > y('message') && y('message') > y('whyText')
    && y('whyText') > y('status') && y('status') > y('cancel'));
  assert.equal(y('cancel'), y('confirm'));
  // Every element stays inside the dialog face, so nothing bleeds onto the veil.
  const p = box({ position: theme.layout.exitMenu.panel.slice(0, 2), size: theme.layout.exitMenu.panel.slice(2) });
  for (const n of order) { const c = box(frame(n)); assert.ok(c.l >= p.l && c.r <= p.r && c.b >= p.b && c.t <= p.t, n); }
  // The modal blocker sits below every interactive child (no click-through to the battle).
  const blocker = panel.children.indexOf(frame('blocker'));
  for (const n of ['help', 'cancel', 'confirm']) assert.ok(panel.children.indexOf(frame(n)) > blocker);
});

test('pause and guide panels keep outside blockers below their interior catch and actions', () => {
  const controls = gameLayout().controls;
  const menu = named(controls, 'runMenu');
  const guide = child(named(controls, 'exitPanel'), 'guide');
  for (const panel of [menu, guide]) {
    assert.equal(child(panel, 'catch')?.kind, 'cursorArea');
    assert.equal(child(panel, 'catch').focusable, false);
    assert.ok(panel.children.indexOf(child(panel, 'catch')) > panel.children.indexOf(child(panel, 'blocker')));
  }
  assert.ok(child(menu, 'resume').position[1] > child(menu, 'help').position[1]);
  assert.ok(child(menu, 'map').position[1] > child(menu, 'abandon').position[1]);
  for (const name of ['battle', 'map', 'resources']) {
    const section = child(guide, name);
    assert.equal(section?.kind, 'container');
    for (let row = 1; row <= 4; row++) {
      assert.equal(child(section, `action${row}`).kind, 'text');
      assert.equal(child(section, `how${row}`).kind, 'text');
    }
  }
});
