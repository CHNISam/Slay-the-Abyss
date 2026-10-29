import test from 'node:test';
import assert from 'node:assert/strict';
import { relicViewControls } from '../scripts/relic-view-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';

test('owned relics use disc art slots in the top bar and detail rows', () => {
  const [bar, panel] = relicViewControls(theme), v = theme.layout.relicView;
  assert.equal(bar.name, 'relicBar');
  assert.equal(bar.children.length, v.bar.count);
  bar.children.forEach((slot, i) => {
    assert.deepEqual(slot.position, [v.bar.origin[0] + v.bar.step * i, v.bar.origin[1]]);
    assert.deepEqual(slot.size, [v.bar.disc, v.bar.disc]);
    assert.deepEqual(slot.children.map(c => c.name), ['rim', 'face', 'light', 'icon', 'hit']);
    assert.equal(slot.children[0].image, theme.image.disc);
    // Clear of the title and the 遗物 button.
    assert.ok(slot.position[0] - v.bar.disc / 2 >= theme.layout.nativeNode.topBar.title[2] / 2);
    assert.ok(slot.position[0] + v.bar.disc / 2 <= theme.layout.deckView.relicEntry[0] - theme.layout.deckView.relicEntry[2] / 2);
  });
  const rows = panel.children.filter(c => /^row\d+$/.test(c.name));
  assert.equal(rows.length, v.rows.length * v.columns.length);
  for (const row of rows) {
    const names = row.children.map(c => c.name);
    for (const n of ['slot', 'name', 'chip', 'description']) assert.ok(names.includes(n), n);
    const slot = row.children.find(c => c.name === 'slot');
    assert.deepEqual(slot.size, [v.disc, v.disc]);
    assert.ok(slot.position[0] + v.disc / 2 < v.name[0] - v.name[2] / 2, 'name clears the art disc');
    assert.ok(Math.abs(row.position[0]) + v.row[0] / 2 <= v.panel[2] / 2);
  }
  assert.equal(panel.isolateNavigation, true);
  const json = JSON.stringify(panel);
  assert.doesNotMatch(json.replace(/"(name|kind|image|align|valign|colour)":"[^"]*"/g, ''), /"content":"[A-Za-z]{3,}/);
});
