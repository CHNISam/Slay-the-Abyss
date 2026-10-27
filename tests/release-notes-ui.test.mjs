import test from 'node:test';
import assert from 'node:assert/strict';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { assertNativeUiCapacity, buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { capacityProblems, textConflicts } from './helpers/ui-readability.mjs';

const child = (parent, name) => parent.children.find(control => control.name === name);
const tree = () => {
  const layout = gameLayout();
  return { layout, menu: layout.controls.find(control => control.name === 'menuPanel'),
    panel: layout.controls.find(control => control.name === 'releaseNotesPanel') };
};
const frame = control => [...control.position, ...control.size];
const overlap = (a, b) => [0, 1].every(i => Math.abs(a[i] - b[i]) < (a[i + 2] + b[i + 2]) / 2);
const labels = button => Object.values(child(button, 'hit').states).map(state => child(child(child(button, 'hit'), state), 'label'));

test('notice is a native isolated manual overlay with a full-canvas blocker above every game page', () => {
  const { layout, menu, panel } = tree();
  assertNativeUiCapacity(layout);
  assert.equal(panel.visible, false);
  assert.equal(panel.isolateNavigation, true);
  assert.equal(child(panel, 'blocker').kind, 'cursorArea');
  assert.equal(child(panel, 'blocker').focusable, false);
  assert.deepEqual(child(panel, 'blocker').size, theme.canvas.base);
  assert.equal(layout.controls.at(-1), panel);
  assert.equal(labels(child(menu, 'releaseNotes'))[0].text.content, '更新公告');
  assert.equal(child(menu, 'codeVersion').text.content, '', 'version is injected from build provenance, never invented in layout');
  assert.ok(panel.children.indexOf(child(panel, 'blocker')) < panel.children.indexOf(child(panel, 'close')));
  for (const name of ['history', 'current', 'newer', 'older', 'previous', 'next', 'close']) {
    const button = child(panel, name), hit = child(button, 'hit');
    assert.equal(hit.kind, 'presetButton');
    assert.ok(button.size.every(value => value >= 48));
    assert.deepEqual(Object.keys(hit.states), ['normal', 'hover', 'pressed', 'disabled']);
    assert.equal(labels(button).length, 4);
    for (const label of labels(button)) {
      assert.equal(label.text.autoSize, false);
      assert.ok(label.size[1] >= theme.layout.nativeText.lineHeight);
      assert.ok([...label.text.content].length * label.text.fontSize <= label.size[0]);
    }
  }
});

test('seven native text rows, metadata, version navigation and actions are bounded and do not overlap', () => {
  const { menu, panel } = tree(), l = theme.layout.releaseNotes;
  const rowControls = panel.children.filter(control => /^row\d+$/.test(control.name));
  assert.equal(rowControls.length, l.rows);
  assert.equal(l.rows, 7);
  assert.ok(l.rowCharacters * theme.font.body <= l.row[2], 'worst-case full-width glyphs fit without auto-shrink');
  for (const row of rowControls) {
    assert.equal(row.text.autoSize, false);
    assert.equal(row.text.align, 'left');
    assert.ok(row.size[1] >= theme.layout.nativeText.lineHeight);
  }
  const top = ['title', 'build', 'history', 'current', 'version', 'date', 'newer', 'older'].map(name => child(panel, name));
  const bottom = ['previous', 'next', 'page', 'close'].map(name => child(panel, name));
  const all = [...top, ...rowControls, ...bottom];
  for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) {
    assert.ok(!overlap(frame(all[i]), frame(all[j])), `${all[i].name} overlaps ${all[j].name}`);
  }
  for (const item of [child(menu, 'releaseNotes'), child(menu, 'codeVersion')]) {
    assert.ok(!overlap(frame(item), theme.layout.nativeMenu.start), `${item.name} overlaps the start action`);
  }
  for (const device of [...Object.values(theme.canvas.devices), [2340, 1080]]) {
    const scale = Math.min(device[0] / theme.canvas.base[0], device[1] / theme.canvas.base[1]);
    for (const control of [...all, child(menu, 'releaseNotes'), child(menu, 'codeVersion')]) {
      for (const [i, margin] of [theme.canvas.safe.x, theme.canvas.safe.y].entries()) {
        assert.ok((Math.abs(control.position[i]) + control.size[i] / 2 + margin) * scale <= device[i] / 2,
          `${control.name} exceeds device ${device}`);
      }
    }
  }
});

test('notice geometry follows its own theme tokens without changing card or battle layout', () => {
  const custom = structuredClone(theme);
  custom.layout.releaseNotes.entry[0] = 200;
  custom.layout.releaseNotes.close[0] = 400;
  const layout = gameLayout(custom);
  const menu = layout.controls.find(control => control.name === 'menuPanel');
  const panel = layout.controls.find(control => control.name === 'releaseNotesPanel');
  assert.deepEqual(child(menu, 'releaseNotes').position, [200, theme.layout.releaseNotes.entry[1]]);
  assert.deepEqual(child(panel, 'close').position, [400, theme.layout.releaseNotes.close[1]]);
  assert.deepEqual(layout.controls.find(control => control.name === 'battlePanel'), tree().layout.controls.find(control => control.name === 'battlePanel'));
});

test('real native host covers honest history, long Unicode pagination, modal gestures and controller Cancel', () => {
  buildUI();
  const result = runLua('tests/lua/game_ui_release_notes.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /^LUA_GAME_UI_RELEASE_NOTES_PASS 9$/m);
  const snapshots = result.stdout.split(/\r?\n/).filter(line => line.startsWith('UI_READABILITY\t'));
  assert.equal(snapshots.length, 4);
  for (const snapshot of snapshots) {
    const [, name, json] = snapshot.split('\t');
    // These controls explicitly disable auto-shrinking, so check their configured
    // font rather than the generic fixture's smaller declared minimum.
    const nodes = JSON.parse(json).nodes.filter(node => node.path.startsWith('/releaseNotesPanel/'))
      .map(node => ({ ...node, minimum: node.font }));
    assert.deepEqual(capacityProblems(nodes, theme.layout.nativeText.lineHeight), [], name);
    assert.deepEqual(textConflicts(nodes, () => 'notice'), [], name);
  }
});
